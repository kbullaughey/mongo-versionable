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

  it "should have a default number of inter-root diffs" do
    KeepsDiffs.versions_between_roots.should == 20
  end

  it "can configure a different number of versions to keep" do
    KeepsDiffs.versions_between_roots = 11
    KeepsDiffs.versions_between_roots.should == 11
    KeepsDiffs.set_versions_between_roots 12
    KeepsDiffs.versions_between_roots.should == 12
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
end

# END
