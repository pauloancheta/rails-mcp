# frozen_string_literal: true

require "mcp"

module RailsMcp
  module Tools
    class FindRecord < MCP::Tool
      tool_name "find_record"
      description "Find a single record by primary key"
      input_schema(
        properties: {
          model: { type: "string", description: "Model class name, e.g. \"User\"" },
          id: { type: "integer", description: "Primary key value" },
          fields: { type: "array", description: "Columns to return. Defaults to [id, created_at, updated_at]",
                    items: { type: "string" } }
        },
        required: %w[model id]
      )

      def self.call(model:, id:, server_context:, fields: [])
        result = Database::RoleProxy.with_role do
          klass  = Database::ModelResolver.resolve(model)
          record = klass.find_by(klass.primary_key => id)

          raise Database::ModelResolver::UnknownModel, "#{model} with id=#{id} not found" unless record

          # Pre-query: resolve and validate fields against the same allowed set QueryBuilder uses
          allowed  = allowed_columns(klass)
          resolved = Array(fields).map(&:to_s)
          resolved = RailsMcp.configuration.default_fields.map(&:to_s) & allowed if resolved.empty?

          unknown = resolved - allowed
          raise Database::QueryBuilder::Error, "Unknown field(s): #{unknown.join(", ")}" if unknown.any?

          # Post-query: strip denied columns from output regardless of how resolved was built
          resolved
            .reject { |f| RailsMcp.configuration.column_denied?(f) }
            .to_h { |f| [f, record.public_send(f)] }
        end
        MCP::Tool::Response.new([{ type: "text", text: result.to_json }])
      end

      def self.allowed_columns(klass)
        Database::ColumnPolicy.allowed_for(klass)
      end

      private_class_method :allowed_columns
    end
  end
end
