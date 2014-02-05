require 'spec_helper'

describe "MongoVersionable module unit test" do
  it "raises an error if a connection has not been given" do
    MongoVersionable.disconnect
    expect { 
      MongoVersionable.connection
    }.to raise_error(RuntimeError, /Connection missing/)
  end

  context "with a connection" do
    before :all do
      MongoVersionable.use_connection Mongo::MongoClient.new
    end

    it "can specify a mongo connection" do
      MongoVersionable.connection.should be_a(Mongo::MongoClient)
    end

    context "using a database" do
      before :all do
        MongoVersionable.use_database "mongo_versionable_test"
      end

      it "can specify a database" do
        MongoVersionable.database.should be_a(Mongo::DB)
      end
    end
  end
end

# END
