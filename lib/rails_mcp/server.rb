# frozen_string_literal: true

require "mcp"

module RailsMcp
  module Server
    class << self
      def transport
        @transport ||= build_transport
      end

      def tool(name, &)
        dsl = ToolDSL.new(name)
        dsl.instance_eval(&)
        @custom_tools ||= []
        @custom_tools << dsl.to_mcp_tool
      end

      def all_tools
        built_in_tools + (@custom_tools || [])
      end

      # Allows tests and reloads to reset state
      def reset!
        @transport    = nil
        @custom_tools = nil
      end

      private

      def built_in_tools
        [
          Tools::ListModels,
          Tools::DescribeModel,
          Tools::QueryRecords,
          Tools::FindRecord,
          Tools::CountRecords
        ]
      end

      def build_transport
        mcp_server = MCP::Server.new(
          name: "rails-mcp",
          version: RailsMcp::VERSION,
          tools: all_tools
        )
        MCP::Server::Transports::StreamableHTTPTransport.new(mcp_server, stateless: true)
      end
    end
  end
end
