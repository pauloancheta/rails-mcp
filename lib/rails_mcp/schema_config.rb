# frozen_string_literal: true

require "yaml"

module RailsMcp
  class SchemaConfig
    class Error < StandardError; end

    def initialize(path)
      @path = path.to_s
      @data = load_yaml!
    end

    def accessible?(model_name)
      @data.key?(model_name.to_s)
    end

    def model_names
      @data.keys
    end

    # Returns the column allowlist for a model, or [] if model is not in schema.
    def allowed_columns(model_name)
      Array(@data[model_name.to_s]).map(&:to_s)
    end

    private

    def load_yaml!
      raise Error, "Schema file not found: #{@path}" unless File.exist?(@path)

      data = YAML.safe_load_file(@path)
      raise Error, "Schema file must contain a YAML mapping" unless data.is_a?(Hash)

      validate!(data)
      data
    end

    def validate!(data)
      data.each do |model_name, columns|
        unless model_name.is_a?(String) && model_name.match?(/\A[A-Z][A-Za-z0-9:]*\z/)
          raise Error, "Invalid model name in schema: #{model_name.inspect}"
        end

        unless columns.is_a?(Array) && columns.all?(String)
          raise Error, "Columns for #{model_name} must be an array of strings"
        end
      end
    end
  end
end
