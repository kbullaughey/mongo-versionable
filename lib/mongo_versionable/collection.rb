module MongoVersionable
  # This module is included in any class that you want to make versionable
  #
  # Versions are reconstructed from a 'tip' document, which is a complete version
  # of a document, and zero or more diffs. The tip is the most recent version and
  # older versions are arrived at by applying one or more diffs, in reverse
  # order. I refer to the documents stored in a class's version collection as a
  # version set. There may be more than one version set for any given document, 
  # as at most versions_between_tips diffs can be stored in any version set. 
  # At the root level, each version set as a time stamp (key 't'), that marks
  # the time of the oldest version (times are stored as floats using the
  # MongoVersionable::FastTime class). 
  #
  # Each time a diff is constructed, the current time is recorded and stored
  # with the diff in an array 'diffs'. Notice that this time is not the time
  # the document created by applying the diff was snapped, rather it is the
  # cutoff time beyond which one would not want to apply this diff. (The time
  # the snapshot was taken is stored in the preceding diff or in the case of
  # the first diff, the root-level timestamp). In order to resolve which diff 
  # and version set to use, I must store n times where n-1 is the number of 
  # diffs (with one extra stamp to resolve which version set to use). This 
  # way I only store the root-level timestamp once when the version set is 
  # created, and query the version set by finding the one with the greatest 
  # root-level time that is less than the time for which I'd like to reconstruct
  # a version. Then I apply all diffs that have times greater than the time of
  # interest. The result will be an object that existed at the time of interest,
  # at least to the resolution of snaps taken.
  #
  # It requires that the class have a class method 'collection' that returns
  # a Mongo::Collection object.
  module Collection
    extend Forwardable

    #--------------
    # Class Methods
    #--------------

    module ClassMethods
      # Snap a version of the object at the given id
      def snap_version_by_id(id)
        snap_version_by_query '_id' => id
      end

      def last_time_of_version_set(version_set)
        diffs = version_set['diffs']
        return version_set['t'] if diffs.nil? or diffs.empty?
        diffs.last['t']
      end

      def last_version_at(id)
        version_set = find_version_set id
        return nil if version_set.nil?
        last_time_of_version_set version_set
      end

      # Use a query to locate the first object, and snap its version. Only the
      # first object will be versioned.
      def snap_version_by_query(doc, opts = {})
        json = collection.find_one doc, opts
        snap_version json unless json.nil?
      end

      # Reconstruct the version that was snapped most recently before t.
      def reconstruct_version_at(t, id)
        t = t.fractional_seconds if t.kind_of? FastTime
        raise TypeError, "Expecting t to be a FastTime or Float" unless
          t.is_a? Float
        version_set = find_version_set id, t
        return nil if version_set.nil?
        version = version_set['tip']
        
        # Apply all diffs with obsolescence times greater than t
        version_set['diffs'].reverse.each do |diff|
          break unless t < diff['t']
          version = Diff.apply_to version, diff['d']
        end
        version
      end

      # Returns an array of tuples of the form (t, ver)
      def explode_versions(version_set)
        # Instantiate all the versions described by diffs in this version set.
        v = version_set['tip']
        versions = [v]

        # We work our way backward in time, but unshifting onto the versions
        # array so that the result is a forward-chronological array of versions
        # with the right most equaling the tip and the left most equaling the
        # very first snapped version for this version set.
        diffs = version_set['diffs']
        diffs.reverse.each do |diff|
          v = Diff.apply_to v, diff['d']
          versions.unshift v
        end

        # Get the corresponding array of times. The first time is the main one
        # listed on the version_set. Followed by the times of each diff.
        times = [version_set['t']] + diffs.collect{|diff| diff['t']}
        [times,versions].transpose
      end

      # Alter the history in such a way that it is consistent with the object
      # have data represented by ver at time t.
      #
      # The algorithm works by reconstructing all versions, then injecting the
      # new version to the correct spot in the chronological list, and then
      # reconstructing the version_set based on the new sequence.
      #
      # Warning: This method can cause conflicts if versions to the object are
      # concurrently snapped while it is running.
      def inject_historical_version(t, new_ver)
        id = new_ver['_id']
        if t > last_version_at(id)
          snap_version(new_ver, t)
          return
        end
        version_set = find_version_set id, t

        # We'll use this query later when we adjust all subsequent version sets.
        subsequent_query = {'tip._id' => id}

        version_sets = []
        unless version_set.nil?
          raise InvalidHistory, "Invalid version_set time" if
            version_set['t'] > t
          version_sets.push version_set

          # Adjust the query so we only get version sets after this one.
          last_time = last_time_of_version_set version_set
          subsequent_query.merge! t: {:$gt => last_time}
        end

        # Get all the version sets (if any) that follow.
        opts = {:sort => {:t => Mongo::ASCENDING}}
        version_sets += version_collection.find(subsequent_query, opts).to_a

        versions = version_sets.flat_map{|vset| explode_versions vset}

        # Remove the version sets we'll rewrite
        version_set_ids = version_sets.collect{|s| s['_id']}
        version_collection.remove _id: {:$in => version_set_ids}

        # Split the time,version tuples into those that are before the injection
        # and those that are later.
        earlier, later = versions.partition{|tm,v| tm < t}

        # Make a new list including the injected version
        versions = earlier + [[t,new_ver]] + later

        # Re-snap all the versions
        versions.each do |t,ver|
          snap_version ver, t
        end
      end

      def append_version(version_set, new_tip, t)
        # Get the current tip of the version set
        old_tip = version_set['tip']

        # This diff can be applied to new_tip to reconstruct the old tip, which
        # we'll no longer store.
        diff = Diff.new(new_tip, old_tip).hash

        # Put the new tip on the version set and add the diff so we can recreate
        # the version we just supplanted.
        version_set['tip'] = new_tip
        version_set['diffs'].push 't' => t, 'd' => diff
      end

      # Take a serialized object (Hash) and snap a version of it. Diffs are
      # stored backwards from the tip. So the tip is the latest copy and older
      # versions are reconstructed by applying diffs successively to a tip.
      #
      # new_tip must have an _id
      def snap_version(new_tip, t=nil)
        raise TypeError, "Expecting Hash" unless new_tip.kind_of? Hash
        raise ArgumentError, "No _id" unless new_tip.include? '_id'
        version_set = find_version_set new_tip['_id']

        # If there's no version set yet or if the one found has too many diffs, 
        # create a new one.
        if version_set.nil? or version_set['diffs'].length >= versions_between_tips
          version_set = new_version_set(new_tip)
          if t.nil?
            t = version_set['t']
          else
            # If we're given a particular time, we need to set that
            version_set['t'] = t
            version_collection.save version_set
          end
          return t
        end

        # Default time is now.
        t = FastTime.new.fractional_seconds if t.nil?

        # Append the version and save the set.
        append_version version_set, new_tip, t
        version_collection.save version_set

        # Return the time, in case we want the exact snapshot time.
        return t
      end

      def unpersisted_new_version_set(tip, t)
        doc = {'tip' => tip, 't' => t, 'diffs' => []}
      end

      # Create a new version set, starting with tip.
      def new_version_set(tip, t=FastTime.new.fractional_seconds)
        version_set = unpersisted_new_version_set(tip, t)
        version_collection.insert version_set
        version_set
      end

      # Find a version set by object id and (optionally) time. If no time is
      # given then the most recent version set will be returned. If a time is
      # given then it will be the most recent one started that is before the
      # given time, t.
      def find_version_set(id, t = nil)
        query = {'tip._id' => id}
        query.merge! :t => {:$lte => t} unless t.nil?
        version_collection.find_one query, {:sort => {:t => Mongo::DESCENDING}}
      end

      # Return the collection object for this classes version collection
      def version_collection
        MongoVersionable.database[version_collection_name]
      end

      # Set all the defaults for a versionable collection
      def set_versionable_defaults
        self.versions_between_tips = 20
        self.version_collection_name = inferred_version_collection_name
        self.version_serialization_method = :as_json
      end

      # Allow the default versions between tips to be overridden. After this
      # number of diffs as been written, a new tip will be added. This method
      # can either be called as an assignment (in which case you'll need to
      # specify a receiver, such as self) or as a set_* alias.
      def versions_between_tips=(n)
        raise TypeError, "Expecting integer" unless n.kind_of? Integer
        @versions_between_tips = n
      end
      alias_method :set_versions_between_tips, :versions_between_tips=

      # Get the current setting for this class for the number of versions
      # between tips.
      def versions_between_tips
        @versions_between_tips
      end

      # Allow the default version collection name to be overridden. This
      # collection will be used to store the diffs. This method can either be
      # called as an assignment (in which case you'll need to specify a 
      # receiver, such as self) or as a set_* alias.
      def version_collection_name=(name)
        raise TypeError, "Expecting string" unless name.kind_of? String
        @version_collection_name = name
      end
      alias_method :set_version_collection_name, :version_collection_name=

      # Get the current setting for the collection name storing the versions
      def version_collection_name
        @version_collection_name
      end

      # Allow the default version serialization method name to be overridden. 
      # This method will be used to produce the hash that is used to produce the
      # diffs that comprise the stored versions. This method can either be
      # called as an assignment (in which case you'll need to specify a 
      # receiver, such as self) or as a set_* alias.
      def version_serialization_method=(name)
        raise TypeError, "Expecting symbol" unless name.kind_of? Symbol
        @version_serialization_method = name
      end
      alias_method :set_version_serialization_method, :version_serialization_method=

      # Get the current setting for the collection name storing the versions
      def version_serialization_method
        @version_serialization_method
      end

      # Guess a name for the collection based on the class name
      def inferred_version_collection_name
        self.to_s.underscore.gsub(%r{/}, ".") + "_versions"
      end
    end

    # Perform setup upon inclusion of this module into a class. Notice that this
    # mixin must be included in a class, and not a module. 
    def self.included(c)
      raise TypeError, "Must be included by class" unless c.kind_of? Class
      c.extend ClassMethods
      c.set_versionable_defaults
    end

    #-----------------
    # Instance Methods
    #-----------------

    # Accessor for mapping instance methods to class methods via Forwardable
    def self_class
      self.class
    end

    def_delegators :self_class, :version_serialization_method, 
      :version_collection_name, :versions_between_tips, :version_collection

    def inject_historical_version_at(t)
      new_tip = send(version_serialization_method)
      self.class.inject_historical_version t, new_tip
    end

    # Use the configured serialization method to write a version of the current 
    # instance.
    def snap_version
      new_tip = send(version_serialization_method)
      self_class.snap_version new_tip
    end

    # Instead of snapping the instance, snap whatever version is currently 
    # persisted.
    def snap_persisted_version
      self_class.snap_version_by_id versionable_deduce_id
    end

    # Provide instance methods of various class methods
    def version_serialization_method
      self.class.version_serialization_method
    end

    # Find an old version of this instance
    def reconstruct_version_at(t)
      self_class.reconstruct_version_at t, versionable_deduce_id
    end

    # Override this method if you need another way of getting the id
    def versionable_deduce_id
      respond_to?(:id) ? id : self['_id']
    end

    def last_version_at
      self.class.last_version_at versionable_deduce_id
    end
  end
end
