# Mute migration notifications.
RailsMetrics.mute_class_method!(ActiveRecord::Migrator, :migrate)

# Setup to ignore any query which is not a SELECT, INSERT, UPDATE
# or DELETE and queries made by the own store.
RailsMetrics.ignore :invalid_queries do |name, payload|
  name == "active_record.sql" &&
    (payload[:sql] !~ /^(SELECT|INSERT|UPDATE|DELETE)/ ||
    RailsMetrics.store.connections_ids.include?(payload[:connection_id]))
end

module RailsMetrics
  module ORM
    # Include in your model to store metrics. For ActiveRecord, you need the
    # following setup:
    #
    #   script/generate model Metric script/generate name:string duration:integer
    #     instrumenter_id:integer payload:text started_at:datetime created_at:datetime --skip-timestamps
    #
    # You can use any model name you wish. Next, you need to include
    # RailsMetrics::ORM::ActiveRecord:
    #
    #   class Metric < ActiveRecord::Base
    #     include RailsMetrics::ORM::ActiveRecord
    #   end
    #
    module ActiveRecord
      extend  ActiveSupport::Concern
      include RailsMetrics::Store

      included do
        # Create a new connection pool just for the given resource
        establish_connection(Rails.env)

        # Set required validations
        validates_presence_of :name, :duration, :started_at

        # Serialize payload data
        serialize :payload

        # Select scopes
        scope :by_name,            lambda { |name| where(:name => name) }
        scope :by_instrumenter_id, lambda { |instrumenter_id| where(:instrumenter_id => instrumenter_id) }

        # Order scopes
        # We need to add the id in the earliest and latest scope since the database
        # does not store miliseconds. The id then comes as second criteria, since
        # the ones started first are first saved in the database.
        scope :earliest, order("started_at ASC, id ASC")
        scope :latest,   order("started_at DESC, id DESC")
        scope :slowest,  order("duration DESC")
        scope :fastest,  order("duration ASC")
      end

      module ClassMethods
        def connections_ids
          self.connection_pool.connections.map(&:object_id)
        end
      end

    protected

      def save_metrics!
        save!
      end
    end
  end
end