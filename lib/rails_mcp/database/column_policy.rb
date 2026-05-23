# frozen_string_literal: true

module RailsMcp
  module Database
    # Single source of truth for which columns are visible for a given AR class.
    # Applies schema_file allowlist, default_fields auto-include, and denied_columns
    # in that order.
    module ColumnPolicy
      def self.allowed_for(klass)
        schema = RailsMcp.schema_config
        cols = if schema
                 auto = RailsMcp.configuration.default_fields.map(&:to_s) & klass.column_names
                 (schema.allowed_columns(klass.name) + auto).uniq
               else
                 klass.column_names
               end
        cols.reject { |col| RailsMcp.configuration.column_denied?(col) }
      end
    end
  end
end
