# frozen_string_literal: true

module RailsMcp
  module Database
    module ModelResolver
      SAFE_CONSTANT_PATTERN = /\A[A-Z][A-Za-z0-9:]*\z/

      class Error < StandardError; end
      class AccessDenied < Error; end
      class UnknownModel < Error; end

      def self.resolve(model_name)
        klass = find_class!(model_name)
        assert_accessible!(klass)
        klass
      end

      def self.all_accessible
        eager_load_models!
        ActiveRecord::Base.descendants
                          .reject(&:abstract_class?)
                          .select { |k| accessible?(k) }
      end

      private_class_method def self.find_class!(name)
        raise UnknownModel, "Invalid model name: #{name.inspect}" unless name.to_s.match?(SAFE_CONSTANT_PATTERN)

        klass = name.to_s.safe_constantize
        unless klass && klass < ActiveRecord::Base && !klass.abstract_class?
          raise UnknownModel, "Unknown model: #{name}"
        end

        klass
      end

      private_class_method def self.assert_accessible!(klass)
        raise AccessDenied, "Model #{klass.name} is not accessible" unless accessible?(klass)
      end

      private_class_method def self.accessible?(klass)
        # Schema file takes precedence over allowed_models/denied_models
        schema = RailsMcp.schema_config
        return schema.accessible?(klass.name) if schema

        config = RailsMcp.configuration
        name   = klass.name

        return false if config.denied_models.include?(name)
        return true  if config.allowed_models.empty?

        config.allowed_models.include?(name)
      end

      private_class_method def self.eager_load_models!
        return unless defined?(Rails)

        Rails.application.eager_load! unless Rails.application.config.eager_load
      rescue StandardError
        # best-effort in environments where eager load is not fully available
      end
    end
  end
end
