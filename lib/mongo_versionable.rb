require 'active_support/core_ext/string/inflections'
require 'mongo'

module MongoVersionable
  @config = {}
  def self.reconnect_method(&block)
    raise ArgumentError, "Must give block" unless block_given?
    @reconnect = block
  end

  def self.reconnect
    raise "No reconnect method defined" if @reconnect.nil?
    @reconnect.call
  end

  # Specify a MongoClient object
  def self.use_connection(conn)
    raise TypeError, "Expecting MongoClient object" unless 
      conn.kind_of? Mongo::MongoClient
    config[:connection] = conn
  end

  # Stop using the current connection (if one existed)
  def self.disconnect
    config[:connection] = nil
  end

  # Give the database name to use.
  def self.use_database(name)
    config[:database] = name
  end

  # Accessor for getting the connection object
  def self.connection
    if config[:connection].nil? and @reconnect
      use_connection reconnect
    end
    config[:connection] or raise RuntimeError, "Connection missing"
  end

  # Accessor for the MongoDB object
  def self.database
    connection[config[:database]]
  end

  # I think this will be threadsafe
  def self.config
    @config
  end
end

require 'mongo_versionable/exceptions'
require 'mongo_versionable/version'
require 'mongo_versionable/fast_time'
require 'mongo_versionable/diff'
require 'mongo_versionable/collection'
