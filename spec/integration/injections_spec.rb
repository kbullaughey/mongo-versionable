require 'spec_helper'

class HistoryInjectionTest
  attr_accessor :data

  include ::MongoVersionable::Collection
  set_versions_between_tips 4

  module ClassMethods
    def deserialize(hash)
      new(hash)
    end
  end
  extend ClassMethods

  def initialize(hash)
    self.data = hash.deep_dup
    data['_id'] ||= BSON::ObjectId.new
  end

  def version_originale
    self.class.new '_id' => id
  end

  def id
    data['_id']
  end

  def copy
    self.class.new(data)
  end

  def as_json
    data.deep_dup
  end

  def properties
    %w(a b c d)
  end

  def pick_property
    properties[Random.rand(properties.length)]
  end

  def possible_values
    [nil] + %w(french fish eat peanut butter)
  end

  def pick_value
    possible_values[Random.rand(possible_values.length)]
  end

  def mutate
    val = pick_value
    p = pick_property
    if val.nil?
      data.delete p
      [p, nil]
    else
      data[p] = val
      [p, val]
    end
  end
end

describe "History injections" do
  it "passes a simple test" do
    obj = HistoryInjectionTest.new 'a' => 1
    id = obj.id
    snap_time_1 = obj.snap_version
    obj.data['b'] = 2
    snap_time_2 = obj.snap_version
    old_obj = HistoryInjectionTest.deserialize(obj.reconstruct_version_at snap_time_1)
    expect(old_obj.data['a']).to eq(1)
    expect(old_obj.data['b']).to be_nil
    old_obj.data['c'] = 3
    midpoint = (snap_time_1 + snap_time_2) / 2.0
    old_obj.inject_historical_version_at midpoint

    v1 = obj.reconstruct_version_at snap_time_1
    v2 = obj.reconstruct_version_at midpoint
    v3 = obj.reconstruct_version_at snap_time_2
    v4 = obj.reconstruct_version_at Time.now.utc.to_f

    expect(v1).to eq({'_id' => id, 'a' => 1})
    expect(v2).to eq({'_id' => id, 'a' => 1, 'c' => 3})
    expect(v3).to eq({'_id' => id, 'a' => 1, 'b' => 2, 'c' => 3})
    expect(v4).to eq({'_id' => id, 'a' => 1, 'b' => 2, 'c' => 3})
  end

  it "passes tests with one object" do
    reps = 20
    n = 12
    k = 3
    reps.times do |r|
      # Select k versions that will be injected later
      to_inject = (0 ... n).to_a.shuffle.first(k).sort
  
      # Generate n versions
      obj = HistoryInjectionTest.new 'a' => 1
      HistoryInjectionTest.any_instance.stub(:version_originale).
        and_return(HistoryInjectionTest.new '_id' => obj.id, 'a' => 1)
      full_history = []
      initial_history = []
      injected_versions = []
      mutations = []
      n.times do |i|
        if to_inject.include? i
          obj2 = obj.copy
          obj2.data['injections'] = to_inject.select{|j| j <= i}
          time = MongoVersionable::FastTime.new.to_f
          tuple = [time, obj2.as_json]
          injected_versions.push tuple
        else
          mu = obj.mutate
          time = obj.snap_version
          tuple = [time, obj.as_json]
          initial_history.push tuple
          mutations.push [i,mu]
        end
        full_history.push tuple
      end
      expect(full_history.length).to eq(n)
  
      # Check the initial history
      initial_history.each do |time,ver|
        reconstruction = obj.reconstruct_version_at time
        expect(reconstruction).to eq(ver)
      end

      old_history = MongoVersionable.database['history_injection_test_versions'].find('tip._id' => obj.id).sort('t' => 1).to_a.deep_dup;
  
      # Inject the historical versions
      injected_versions.each do |time, ver|
        obj.data = ver.deep_dup
        obj.inject_historical_version_at time
      end
  
      # Compute the expected history. At each injection, we append the index
      # onto the array, and we expect these to accumulate over time.
      full_history.each_with_index do |(time,ver),i|
        subset = to_inject.select{|j| j <= i}
        ver['injections'] = subset unless subset.empty?
      end

      # Check the resulting full history
      full_history.each do |time,ver|
        reconstruction = obj.reconstruct_version_at time
        binding.pry unless reconstruction == ver
        expect(reconstruction).to eq(ver)
      end
    end
  end
end
