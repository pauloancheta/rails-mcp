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
  end
end
