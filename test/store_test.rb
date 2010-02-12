require 'test_helper'

class StoreTest < ActiveSupport::TestCase
  def sample_args
    time = Time.now
    ["rails_metrics.example", time, time + 10, 1, { :some => :info }]
  end

  # We need to mute RailsMetrics, otherwise we get Sqlite3 database lock errors
  def store!(args=sample_args)
    metric = Metric.new
    metric.configure(args)
    metric
  end

  test "sets the name" do
    assert_equal "rails_metrics.example", store!.name
  end

  test "sets the duration" do
    assert_equal 10000, store!.duration
  end

  test "sets started at" do
    assert_kind_of Time, store!.started_at
  end

  test "sets the payload" do
    assert_equal Hash[:some => :info], store!.payload
  end

  test "does not set the instrumenter id from args" do
    assert_nil store!.instrumenter_id
  end
end