require 'active_support/core_ext/object/deep_dup'

module MongoVersionable
  class Diff
    #--------------
    # Class Methods
    #--------------

    # Indicate if both a and b are Hashes (or their descendents).
    def self.both_hashes?(a,b)
       a.kind_of?(Hash) and b.kind_of?(Hash)
    end

    # For a hash to look like a difference hash, it must be a Hash, it must
    # have keys, and it must not have any keys but '_rm' and '_ch'. 
    #
    # Even though a difference hash can be the empty hash, I don't want
    # to assume that the empty hash is a difference hash, because the
    # empty hash might also be a regular value.
    def self.looks_like_diff_hash(x)
      return false unless x.kind_of? Hash
      return false if x.keys.empty?
      return (x.keys - ['_rm', '_ch']).empty?
    end

    # Recursively go through and apply the diff to document a.
    #
    # The returned document will be a copy
    def self.apply_to(a, diff_hash)
      raise ArgumentError, "Cannot apply to nil" if a.nil?
      return a.deep_dup if diff_hash.kind_of?(Hash) and diff_hash.empty?
      raise ArgumentError, "Doesn't look like a difference hash" unless
        looks_like_diff_hash diff_hash
      result = a.deep_dup
      diff_hash['_rm'].each{|k| result.delete k} if diff_hash.include? '_rm'
      if diff_hash.include? '_ch'
        diff_hash['_ch'].each do |key,val|
          if looks_like_diff_hash val
            result[key] = apply_to(a[key], val)
          elsif val.respond_to? :initialize_copy
            result[key] = val.initialize_copy
          else
            result[key] = val
          end
        end
      end
      result
    end

    #-----------------
    # Instance Methods
    #-----------------

    attr_accessor :changes, :removed_keys

    # Produce a diff of a and b which allows b to be reconstructed from a by 
    # applying the diff.
    def initialize(a,b)
      raise TypeError, "Expecting Hashes (got #{a.class}/#{b.class})" unless
        Diff.both_hashes? a, b
      self.removed_keys = a.keys - b.keys
      self.changes = {}
      b.keys.each do |key|
        b_value = b[key]
        if a.include? key
          a_value = a[key]
          if Diff.both_hashes? a_value, b_value
            val_diff = Diff.new(a_value, b_value)
            changes[key] = val_diff unless val_diff.empty?
          else
            changes[key] = b_value unless a_value == b_value
          end
        else
          changes[key] = b_value unless a_value == b_value
        end
      end
    end

    # A diff is empty if there are not changes that would need to be applied 
    # so that a and b are equivalent.
    def empty?
      removed_keys.empty? and changes.empty?
    end

    # Use the (possibly recursive) structure of the diff to make a corresponding hash.
    def hash
      h = {}
      h['_rm'] = removed_keys unless removed_keys.empty?
      h['_ch'] = Hash[changes.collect {|k,v| [k, v.is_a?(Diff) ? v.hash : v]}] unless
        changes.empty?
      h
    end
  end
end
