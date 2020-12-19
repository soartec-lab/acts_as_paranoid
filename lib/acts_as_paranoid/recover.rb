# frozen_string_literal: true

module ActsAsParanoid
  module Recover
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def self.extended(base)
        base.define_callbacks :recover
      end

      def before_recover(method)
        set_callback :recover, :before, method
      end

      def after_recover(method)
        set_callback :recover, :after, method
      end
    end

    def recover(options = {})
      return if !deleted?

      options = {
        recursive: self.class.paranoid_configuration[:recover_dependent_associations],
        recovery_window: self.class.paranoid_configuration[:dependent_recovery_window],
        raise_error: false
      }.merge(options)

      self.class.transaction do
        run_callbacks :recover do
          if options[:recursive]
            recover_dependent_associations(options[:recovery_window], options)
          end
          increment_counters_on_associations
          self.paranoid_value = self.class.paranoid_configuration[:recovery_value]
          if options[:raise_error]
            save!
          else
            save
          end
        end
      end
    end

    def recover!(options = {})
      options[:raise_error] = true

      recover(options)
    end

    def recover_dependent_associations(window, options)
      self.class.dependent_associations.each do |reflection|
        next unless (klass = get_reflection_class(reflection)).paranoid?

        scope = klass.only_deleted.merge(get_association_scope(reflection: reflection))

        # We can only recover by window if both parent and dependant have a
        # paranoid column type of :time.
        if self.class.paranoid_column_type == :time && klass.paranoid_column_type == :time
          scope = scope.deleted_inside_time_window(paranoid_value, window)
        end

        scope.each do |object|
          object.recover(options)
        end
      end
    end
  end
end
