# frozen_string_literal: true

require "mcp"

module RailsMcp
  module Tools
    class CountRecords < MCP::Tool
      tool_name "count_records"
      description "Count records matching hash conditions"
      input_schema(
        properties: {
          model: { type: "string", description: "Model class name, e.g. \"User\"" },
          conditions: { type: "object", description: "Hash of column => value pairs" }
        },
        required: ["model"]
      )

      SCALAR_TYPES = [String, Integer, Float, TrueClass, FalseClass, NilClass].freeze

      def self.call(model:, server_context:, conditions: {})
        count = Database::RoleProxy.with_role do
          klass      = Database::ModelResolver.resolve(model)
          conditions = (conditions || {}).transform_keys(&:to_s)
          allowed    = Database::ColumnPolicy.allowed_for(klass)

          unknown = conditions.keys - allowed
          raise Database::QueryBuilder::Error, "Unknown column(s): #{unknown.join(", ")}" if unknown.any?

          invalid = conditions.reject { |_, v| valid_condition_value?(v) }
          if invalid.any?
            raise Database::QueryBuilder::Error,
                  "Invalid condition value(s) for: #{invalid.keys.join(", ")} (scalars and arrays only)"
          end

          klass.where(conditions).count
        end
        MCP::Tool::Response.new([{ type: "text", text: { count: count }.to_json }])
      end

      def self.valid_condition_value?(value)
        if value.is_a?(Array)
          value.all? { |v| SCALAR_TYPES.any? { |t| v.is_a?(t) } }
        else
          SCALAR_TYPES.any? { |t| value.is_a?(t) }
        end
      end

      private_class_method :valid_condition_value?
    end
  end
end
