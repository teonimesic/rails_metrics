Thread.abort_on_exception = Rails.env.development? || Rails.env.test?

# Add a middleware to exempt /metric notifications

module RailsMetrics
  # Keeps a link to the class which stores the metric. This is set automatically
  # when a module inherits from RailsMetrics::Store.
  mattr_accessor :store
  @@metrics_store = nil

  # Keeps a list of patterns to not be saved in the store. You can add how many
  # you wish:
  #
  #   RailsMetrics.ignore_patterns << /^action_controller/
  #
  mattr_accessor :ignore_patterns
  @@ignore_patterns = []

  # A notification is valid for storing if two conditions are met:
  #
  #   1) The instrumenter id which created the notification is not the same
  #      instrumenter id of this thread. This means that notifications generated
  #      inside this thread are stored in the database;
  #
  #   2) If the notification name does not match any ignored pattern;
  #
  def self.valid_for_storing?(name, instrumenter_id)
    ActiveSupport::Notifications.instrumenter.id != instrumenter_id &&
      !RailsMetrics.blacklist.include?(instrumenter_id) &&
      !self.ignore_patterns.find { |regexp| name =~ regexp }
  end

  # Mute RailsMetrics subscriber during the block.
  def self.mute!
    ActiveSupport::Notifications.instrument("rails_metrics.add_to_blacklist")
    yield
  ensure
    ActiveSupport::Notifications.instrument("rails_metrics.remove_from_blacklist")
  end

  # Keeps a blacklist of instrumenters ids.
  def self.blacklist
    Thread.current[:rails_metrics_instrumenters_blacklist] ||= []
  end
end

ActiveSupport::Notifications.subscribe do |*args|
  name, instrumenter_id = args[0].to_s, args[3]

  if args[0] == "rails_metrics.add_to_blacklist"
    RailsMetrics.blacklist << instrumenter_id
  elsif args[0] == "rails_metrics.remove_from_blacklist"
    RailsMetrics.blacklist.delete(instrumenter_id)
  elsif RailsMetrics.valid_for_storing?(name, instrumenter_id)
    RailsMetrics.store.new.store!(args)
  end
end
