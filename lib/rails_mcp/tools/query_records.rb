# frozen_string_literal: true

require "mcp"

module RailsMcp
  module Tools
    class QueryRecords < MCP::Tool
      tool_name "query_records"
      description "Query records using hash conditions. Returns only id, created_at, and updated_at " \
                  "by default — specify fields to retrieve other columns."
      input_schema(
        properties: {
          model: { type: "string", description: "Model class name, e.g. \"User\"" },
          conditions: { type: "object", description: "Hash of column => value pairs, e.g. {\"active\": true}" },
          fields: { type: "array", description: "Columns to return. Defaults to [id, created_at, updated_at]",
                    items: { type: "string" } },
          limit: { type: "integer", description: "Max records to return (capped at max_limit, default 100)" },
          offset: { type: "integer",
                    description: "Number of records to skip (must not exceed max_offset, default 10000)" },
          order: { type: "string", description: "Order clause, e.g. \"created_at DESC\"" }
        },
        required: ["model"]
      )

      def self.call(model:, server_context:, conditions: {}, fields: [], limit: nil, offset: 0, order: nil)
        records = Database::RoleProxy.with_role do
          klass = Database::ModelResolver.resolve(model)
          Database::QueryBuilder.new(
            klass,
            conditions: conditions || {},
            fields: Array(fields),
            limit: limit,
            offset: offset || 0,
            order: order
          ).execute
        end
        MCP::Tool::Response.new([{ type: "text", text: records.to_json }])
      end
    end
  end
end
