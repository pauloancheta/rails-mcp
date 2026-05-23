# frozen_string_literal: true

require "mcp"

module RailsMcp
  class ToolDSL
    def initialize(name)
      @name             = name.to_s
      @description_text = nil
      @parameters       = []
      @call_block       = nil
    end

    def description(text)
      @description_text = text
    end

    def parameter(name, type:, description: nil, required: false)
      @parameters << { name: name.to_s, type: type.to_s, description: description, required: required }
    end

    def call(&block)
      @call_block = block
    end

    def to_mcp_tool
      name        = @name
      description = @description_text
      parameters  = @parameters
      call_block  = @call_block

      properties = parameters.to_h do |p|
        schema = { type: p[:type] }
        schema[:description] = p[:description] if p[:description]
        [p[:name].to_sym, schema]
      end
      required = parameters.select { |p| p[:required] }.map { |p| p[:name] }
      schema = { properties: properties }
      schema[:required] = required if required.any?

      Class.new(MCP::Tool) do
        tool_name name
        description description
        input_schema(**schema)

        define_singleton_method(:call) do |server_context:, **args|
          call_block.call(args, server_context)
        end
      end
    end
  end
end
