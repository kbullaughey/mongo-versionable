require 'active_support/core_ext/string/inflections'
require 'mongo'

module MongoVersionable
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
    config[:connection] or raise RuntimeError, "Connection never specified"
  end

  # Accessor for the MongoDB object
  def self.database
    connection[config[:database]]
  end

  # I think this will be threadsafe
  def self.config
    @config ||= {}
    @config[Thread.current.object_id] ||= {}
    @config[Thread.current.object_id]
  end
end

require 'mongo_versionable/version'
require 'mongo_versionable/fast_time'
require 'mongo_versionable/diff'
require 'mongo_versionable/collection'
