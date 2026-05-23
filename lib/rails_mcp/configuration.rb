# frozen_string_literal: true

module RailsMcp
  class Configuration
    attr_accessor :database_role,
                  :default_fields,
                  :allowed_models,
                  :denied_models,
                  :denied_columns,
                  :max_limit,
                  :schema_file

    def initialize
      @database_role  = :reading
      @default_fields = %i[id created_at updated_at]
      @allowed_models = []
      @denied_models  = []
      @denied_columns = []
      @max_limit      = 100
      @schema_file    = nil
    end

    def column_denied?(name)
      denied_columns.any? do |pattern|
        pattern.is_a?(Regexp) ? pattern.match?(name.to_s) : pattern.to_s == name.to_s
      end
    end
  end
end
