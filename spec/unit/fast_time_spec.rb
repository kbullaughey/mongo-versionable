require 'spec_helper'

describe MongoVersionable::FastTime do
  before :each do
    @t = Time.now.utc
    @ft = MongoVersionable::FastTime.new @t.to_f
  end

  it "can be initialized with nil" do
    diff = MongoVersionable::FastTime.new.fractional_seconds - @t.to_f
    diff.should < 1.0
  end

  it "can be initialized from a number of seconds" do
    @ft.fractional_seconds.should == @t.to_f
  end

  it "can be converted to a regular time object" do
    @ft.to_time.should be_kind_of(Time)
    @ft.to_time.to_f.should == @t.to_f
    (@t - @ft.to_time).should < 10 ** (-6)
  end

  it "adds properly" do
    (@ft + 1.0).should == @t.to_f + 1.0
  end

  it "subtracts properly" do
    (@ft - 1.0).should == @t.to_f - 1.0
  end

  it "raises an error when not given a float" do
    expect {
      MongoVersionable::FastTime.new(1)
    }.to raise_error(ArgumentError, /Expecting float/)
  end
end

# END


