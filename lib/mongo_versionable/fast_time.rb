# The purpose of this class is to represent a mongoable time that is faster 
# to persist and instantiate than standard time objects. Doing anything
# complicated with it requires conversion to a regular time object.
#
# This class uses a float object for persistance to mongo. It represents the
# (fractional) number of seconds since the epoch in UTC.
module MongoVersionable
  class FastTime
    attr_accessor :fractional_seconds
  
    #-----------------
    # Instance methods
    #-----------------
  
    # Build an instance using either the passed float argument or the current 
    # UTC time if no argument is given.
    def initialize(fsec = nil)
      self.fractional_seconds =
        if fsec.nil?
          Time.now.utc.to_f
        else
          raise ArgumentError, "Expecting float" unless fsec.is_a? Float
          fsec
        end
    end
  
    # Convert to a ruby UTC Time object.
    def to_time
      Time.at(fractional_seconds).utc
    end
  
    def +(x)
      t = fractional_seconds + fractional_seconds_or_else(x)
      FastTime.new t
    end
  
    def -(x)
      t = fractional_seconds - fractional_seconds_or_else(x)
      FastTime.new t
    end
  
    def to_s
      fractional_seconds.to_s
    end
  
    def ==(x)
      fractional_seconds == fractional_seconds_or_else(x)
    end
  
  private
    # Convenience function used internally
    def fractional_seconds_or_else(x)
      x.is_a?(FastTime) ? x.fractional_seconds : x
    end
  end
end

# END
