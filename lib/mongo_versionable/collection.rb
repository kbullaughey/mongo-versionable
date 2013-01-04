module MongoVersionable
  # This module is included in any class that you want to make versionable
  module Collection
    module ClassMethods

      # Set all the defaults for a versionable collection
      def set_versionable_defaults
        self.versions_between_roots = 20
        self.version_collection_name = inferred_version_collection_name
      end

      # Allow the default versions between roots to be overridden. After this
      # number of diffs as been written, a new root will be added. This method
      # can either be called as an assignment (in which case you'll need to
      # specify a receiver, such as self) or as a the set_* alias.
      def versions_between_roots=(n)
        raise TypeError, "Expecting integer" unless n.kind_of? Integer
        @versions_between_roots = n
      end
      alias_method :set_versions_between_roots, :versions_between_roots=

      # Get the current setting for this class for the number of versions
      # between roots.
      def versions_between_roots
        @versions_between_roots
      end

      # Allow the default version collection name to be overridden. This
      # collection will be used to store the diffs. This method can either be
      # called as an assignment (in which case you'll need to specify a 
      # receiver, such as self) or as a the set_* alias.
      def version_collection_name=(name)
        raise TypeError, "Expecting string" unless name.kind_of? String
        @version_collection_name = name
      end
      alias_method :set_version_collection_name, :version_collection_name=

      # Get the current setting for the collection name storing the versions
      def version_collection_name
        @version_collection_name
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
  end
end
