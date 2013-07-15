require 'spec_helper'

describe "Collection integration" do
  before :each do
    clean_db
  end

  before :all do
    class LifeGoal
      attr_accessor :goal, :who, :id

      def self.collection
        MongoVersionable.database['life_goals']
      end
      include MongoVersionable::Collection
      set_versions_between_tips 3

      def initialize(goal = nil, who = nil)
        self.id = BSON::ObjectId.new
        self.goal = goal unless goal.nil?
        self.who = who unless who.nil?
      end

      def as_json
        json = {'_id' => id}
        json['goal'] = goal unless goal.nil?
        json['who'] = who unless who.nil?
        json
      end
    end
  end

  it "is configured to store 3 diffs between tips" do
    LifeGoal.versions_between_tips.should == 3
  end

  it "can create a new version set using snap_version" do
    g = LifeGoal.new('conquer the world', 'Ren')
    g.snap_version
    g.version_collection.count.should == 1
    ver_set = g.version_collection.find_one
    ver_set['tip']['_id'].should == g.id
    ver_set['tip'].should == g.as_json
    ver_set['diffs'].should == []
  end

  context "A saved document" do
    before :each do
      @before_time = MongoVersionable::FastTime.new - 60
      @goal = LifeGoal.new('obtain enlightenment', 'Buddha')
      LifeGoal.collection.save @goal.as_json
    end

    it "can create a new version set from an id" do
      LifeGoal.snap_version_by_id @goal.id
      LifeGoal.version_collection.find_one['tip']['_id'].should == @goal.id
    end

    it "can snap the persisted version using an instance" do
      @goal.goal = "escape rebirth"
      @goal.snap_persisted_version
      g2 = @goal.reconstruct_version_at MongoVersionable::FastTime.new
      g2['goal'].should == "obtain enlightenment"
    end

    it "distinct persisted versions end up with separate records" do
      goal1 = LifeGoal.new('obtain enlightenment', 'Buddha')
      LifeGoal.collection.save(goal1.as_json)
      goal1.snap_persisted_version
      goal2 = LifeGoal.new('die for sins', 'Jesus')
      LifeGoal.collection.save(goal2.as_json)
      goal2.snap_persisted_version
      LifeGoal.version_collection.count.should == 2
    end

    it "can create a new version set using a query" do
      LifeGoal.snap_version_by_query :who => 'Buddha'
      LifeGoal.version_collection.find_one['tip']['_id'].should == @goal.id
    end

    context "Has a diff" do
      before :each do
        @goal.snap_version
        @when = MongoVersionable::FastTime.new.fractional_seconds
        @goal.goal = 'reach nirvana'
        @goal.snap_version
      end

      it "can save a second version and it gets diffed" do
        vset = LifeGoal.version_collection.find_one 'tip._id' => @goal.id
        vset['diffs'].length.should == 1
        vset['diffs'].first['d'].should == {'_ch' => {'goal' => 'obtain enlightenment'}}
        vset['tip']['goal'].should == 'reach nirvana'
        (MongoVersionable::FastTime.new - vset['diffs'].first['t']).
          fractional_seconds.should < 1
      end

      it "can reconstruct the old version" do
        old_version = LifeGoal.reconstruct_version_at @when, @goal.id
        old_version['goal'].should == 'obtain enlightenment'
      end

      it "can reconstruct a version from an instance" do
        old_version = @goal.reconstruct_version_at @when
        old_version['goal'].should == 'obtain enlightenment'
      end

      it "reconstructs a version after t if none exists before it" do
        old_version = @goal.reconstruct_version_at @before_time
        old_version.should_not be_nil
        old_version['goal'].should == 'obtain enlightenment'
      end

      it "only keeps a limited number of diffs" do
        @goal.who = 'Duckie'
        v1 = @goal.as_json
        @goal.snap_version
        t1 = MongoVersionable::FastTime.new.fractional_seconds

        @goal.goal = 'Quack'
        v2 = @goal.as_json
        @goal.snap_version
        t2 = MongoVersionable::FastTime.new.fractional_seconds

        @goal.goal = 'Quack quack!'
        v3 = @goal.as_json
        @goal.snap_version
        t3 = MongoVersionable::FastTime.new.fractional_seconds

        @goal.goal = 'Quack quack quack!!'
        v4 = @goal.as_json
        @goal.snap_version
        t4 = MongoVersionable::FastTime.new.fractional_seconds

        LifeGoal.version_collection.count.should == 2
        vset = LifeGoal.find_version_set @goal.id, t1
        vset['diffs'].length.should == 3

        vset = LifeGoal.find_version_set @goal.id, t3
        vset['diffs'].length.should == 1

        LifeGoal.reconstruct_version_at(t1, @goal.id).should == v1
        LifeGoal.reconstruct_version_at(t2, @goal.id).should == v2
        LifeGoal.reconstruct_version_at(t3, @goal.id).should == v3
        LifeGoal.reconstruct_version_at(t4, @goal.id).should == v4
      end
    end
  end
end

# END
