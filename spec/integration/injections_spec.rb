require 'spec_helper'

class HistoryInjectionTest
  attr_accessor :data

  include ::MongoVersionable::Collection
  set_versions_between_tips 4

  def self.collection
    MongoVersionable.database['life_goals']
  end

  def initialize(hash)
    self.data = hash
    data['_id'] = BSON::ObjectId.new
  end

  def id
    data['_id']
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
    else
      data[p] = val
    end
  end
end

describe "History injections" do
  it "passes tests with one object" do
    reps = 20
    n = 12
    k = 5
    reps.times do
      # Select k versions that will be injected later
      to_inject = (0 ... n).to_a.shuffle.first(k)
  
      # Generate n versions
      obj = HistoryInjectionTest.new 'a' => 1
      full_history = []
      initial_history = []
      injected_versions = []
      n.times do |i|
        if to_inject.include? i
          time = MongoVersionable::FastTime.new.to_f
          tuple = [time, obj.as_json]
          injected_versions.push tuple
        else
          time = obj.snap_version
          tuple = [time, obj.as_json]
          initial_history.push tuple
        end
        full_history.push tuple
  
        obj.mutate
      end
      expect(full_history.length).to eq(n)
  
      # Check the initial history
      initial_history.each do |time,ver|
        reconstruction = obj.reconstruct_version_at time
        expect(reconstruction).to eq(ver)
      end
  
      # Inject the historical versions
      injected_versions.each do |time, ver|
        obj.data = ver.deep_dup
        obj.inject_historical_version_at time
      end
  
      # Check the resulting full history
      full_history.each do |time,ver|
        reconstruction = obj.reconstruct_version_at time
        expect(reconstruction).to eq(ver)
      end
    end
  end
end
