require 'spec_helper'

describe "Collection unit" do
  before :all do
    class KeepsDiffs
      include MongoVersionable::Collection
    end
  end

  before :each do
    KeepsDiffs.set_versionable_defaults
  end

  it "raises NotImplementedError without version_originale" do
    expect {
      KeepsDiffs.new.version_originale
    }.to raise_error(NotImplementedError)
  end

  it "should have a default number of inter-tip diffs" do
    KeepsDiffs.versions_between_tips.should == 20
  end

  it "can see the default number of inter-tip diffs from an instance" do
    KeepsDiffs.new.versions_between_tips.should == 20
  end

  it "can configure a different number of versions to keep" do
    KeepsDiffs.versions_between_tips = 11
    KeepsDiffs.versions_between_tips.should == 11
    KeepsDiffs.set_versions_between_tips 12
    KeepsDiffs.versions_between_tips.should == 12
  end

  it "can infer the collection name" do
    KeepsDiffs.inferred_version_collection_name.should == "keeps_diffs_versions"
  end

  it "uses '.' for namespacing collection name" do
    module Rodant
      class Weasle
        include MongoVersionable::Collection
      end
    end
    Rodant::Weasle.inferred_version_collection_name.should == "rodant.weasle_versions"
  end

  it "uses the inferred version collection name by default" do
    KeepsDiffs.version_collection_name.
      should == KeepsDiffs.inferred_version_collection_name
  end

  it "uses as_json as the default serialization method" do
    KeepsDiffs.version_serialization_method.should == :as_json
  end

  it "can see the the default serialization method from an instance" do
    KeepsDiffs.new.version_serialization_method.should == :as_json
  end

  it "can override the default serialization method" do
    KeepsDiffs.version_serialization_method = :to_mongo
    KeepsDiffs.version_serialization_method.should == :to_mongo
  end

  it "can get the mongo collection object for the version collection" do
    KeepsDiffs.version_collection.should be_kind_of(Mongo::Collection)
  end

  it "can get the mongo collection object for the versions from an instance" do
    KeepsDiffs.new.version_collection.should be_kind_of(Mongo::Collection)
  end
end

# END


