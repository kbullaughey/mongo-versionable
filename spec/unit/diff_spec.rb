require 'spec_helper'

describe "Diff unit test" do
  it "raises error on initialization if not given hashes" do
    expect { MongoVersionable::Diff.new("blah", {}) }.
      to raise_error(TypeError, /Expecting Hash/)
    expect { MongoVersionable::Diff.new({}, "blah") }.
      to raise_error(TypeError, /Expecting Hash/)
  end

  it "is known whether it is empty" do
    MongoVersionable::Diff.new({}, {}).empty?.should be_true
  end

  it "can get a hash of the diff" do
    MongoVersionable::Diff.new({}, {}).hash.should be_a(Hash)
  end

  it "can see deleted fields" do
    MongoVersionable::Diff.new({'a' => 'apple', :b => 'badger'}, {}).
      removed_keys.should == ['a', :b]
  end

  it "sees an added field as a modification" do
    diff = MongoVersionable::Diff.new({}, {:a => 1})
    diff.removed_keys.should be_empty
    diff.changes.should == {:a => 1}
  end

  it "makes a copy if an empty diff is applied" do
    obj = {a: 1}
    obj_copy = MongoVersionable::Diff.apply_to(obj, {})
    obj_copy[:a] = 2
    expect(obj[:a]).to eq(1)
  end

  it "can track changes values in a nested hash" do
    diff = MongoVersionable::Diff.new({:a => {:a1 => 1}}, {:a => {:a1 => 2}})
    diff.changes[:a].should be_a(MongoVersionable::Diff)
    diff.changes[:a].changes.should == {:a1 => 2}
  end

  it "can track new keys in a nested hash" do
    diff = MongoVersionable::Diff.new({:a => {}}, {:a => {:a1 => 1}})
    diff.changes[:a].changes.should == {:a1 => 1}
  end

  it "can track removed keys in a nested hash" do
    diff = MongoVersionable::Diff.new({:a => {:a1 => 1}}, {:a => {}})
    diff.changes[:a].removed_keys.should == [:a1]
  end

  it "can return a hash of the differences for a one-layer object" do
    diff = MongoVersionable::Diff.new({:a => 1, :b => 2}, {:a => 10, :c => 3})
    diff.hash.should == {'_rm' => [:b], '_ch' => {:a => 10, :c => 3}}
  end

  it "can return a hash for the differences in a nested object" do
    o1 = {:a => 1, :b => {:c => 3, :d => 4, :e => {:f => 6}}}
    o2 = {:A => 1, :b => {:c => 30, :d => 4, :e => {:f => 60}}}
    diff = MongoVersionable::Diff.new o1, o2
    diff.hash.should == {'_rm' => [:a], '_ch' => {:A => 1, 
      :b => {'_ch' => {:c => 30, :e => {'_ch' => {:f => 60}}}}}}
  end

  it "doesn't see changes in nested hashes that haven't changed" do
    o1 = {:a => 1, :b => {:c => 3, :d => 4, :e => {:f => 6}}}
    o2 = {:A => 1, :b => {:c => 30, :d => 4, :e => {:f => 6}}}
    diff = MongoVersionable::Diff.new o1, o2
    diff.hash.should == {'_rm' => [:a], '_ch' => {:A => 1, 
      :b => {'_ch' => {:c => 30}}}}
  end

  it "returns an empty hash when there are no differences" do
    o1 = {:a => 1, :b => {:c => 3, :d => 4, :e => {:f => 6}}}
    o2 = {:a => 1, :b => {:c => 3, :d => 4, :e => {:f => 6}}}
    diff = MongoVersionable::Diff.new(o1,o2)
    diff.should be_empty
    diff.hash.should == {}
  end

  it "can apply a diff" do
    MongoVersionable::Diff.apply_to({:a => 1}, {'_ch' => {:b => 2}}).
      should == {:a => 1, :b => 2}
  end

  it "can apply a nested set of changes" do
    dh = {'_ch' => {:b => 2, :c => {'_ch' => {:d => 40}}}}
    MongoVersionable::Diff.apply_to({:a => 1, :c => {:d => 4}}, dh).
      should == {:a => 1, :b => 2, :c => {:d => 40}}
  end

  it "can apply a nested key removal" do
    dh = {'_ch' => {:b => 2, :c => {'_rm' => [:d]}}}
    MongoVersionable::Diff.apply_to({:a => 1, :c => {:d => 4}}, dh).
      should == {:a => 1, :b => 2, :c => {}}
  end

  it "can produce a diff and then apply it to recover the origianl (1)" do
    o1 = {:a => 1, :b => 2}
    o2 = {:a => 10}
    dh = MongoVersionable::Diff.new(o1, o2).hash
    MongoVersionable::Diff.apply_to(o1, dh).should == o2
    dh = MongoVersionable::Diff.new(o2, o1).hash
    MongoVersionable::Diff.apply_to(o2, dh).should == o1
  end

  it "can produce a diff and then apply it to recover the origianl (2)" do
    o1 = {:a => 1, :b => {:c => 3}}
    o2 = {:a => 1}
    dh = MongoVersionable::Diff.new(o1, o2).hash
    MongoVersionable::Diff.apply_to(o1, dh).should == o2
    dh = MongoVersionable::Diff.new(o2, o1).hash
    MongoVersionable::Diff.apply_to(o2, dh).should == o1
  end

  it "can produce an empty diff and then apply it to recover the origianl" do
    o1 = {:a => 1, :b => {:c => 3}}
    o2 = {:a => 1, :b => {:c => 3}}
    dh = MongoVersionable::Diff.new(o1, o2).hash
    MongoVersionable::Diff.apply_to(o1, dh).should == o2
  end

  it "can produce a diff and then apply it to recover the origianl (4)" do
    o1 = {:a => {}}
    o2 = {}
    dh = MongoVersionable::Diff.new(o1, o2).hash
    MongoVersionable::Diff.apply_to(o1, dh).should == o2
    dh = MongoVersionable::Diff.new(o2, o1).hash
    MongoVersionable::Diff.apply_to(o2, dh).should == o1
  end

  it "can produce a diff and then apply it to recover the origianl (5)" do
    o1 = {:a => 1, :b => {:c => {:d => 4}}}
    o2 = {:a => 1, :b => {:d => {:c => 3}}}
    dh = MongoVersionable::Diff.new(o1, o2).hash
    MongoVersionable::Diff.apply_to(o1, dh).should == o2
    dh = MongoVersionable::Diff.new(o2, o1).hash
    MongoVersionable::Diff.apply_to(o2, dh).should == o1
  end
end

# END


