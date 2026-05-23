# frozen_string_literal: true

require "mcp"

module RailsMcp
  module Tools
    class DescribeModel < MCP::Tool
      tool_name "describe_model"
      description "Return schema, columns, and associations for a model"
      input_schema(
        properties: {
          model: { type: "string", description: "Model class name, e.g. \"User\"" }
        },
        required: ["model"]
      )

      def self.call(model:, server_context:)
        result = Database::RoleProxy.with_role do
          klass = Database::ModelResolver.resolve(model)
          {
            model:        klass.name,
            table:        klass.table_name,
            primary_key:  klass.primary_key,
            columns:      column_info(klass),
            associations: association_info(klass)
          }
        end
        MCP::Tool::Response.new([{ type: "text", text: result.to_json }])
      end

      def self.column_info(klass)
        klass.columns
             .reject { |col| RailsMcp.configuration.column_denied?(col.name) }
             .map { |col| { name: col.name, type: col.type.to_s, null: col.null, default: col.default } }
      end

      def self.association_info(klass)
        klass.reflect_on_all_associations.map do |assoc|
          { name: assoc.name.to_s, macro: assoc.macro.to_s, class_name: assoc.class_name }
        end
      end

      private_class_method :column_info, :association_info
    end
  end
end
