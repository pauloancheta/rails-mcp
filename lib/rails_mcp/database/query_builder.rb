# frozen_string_literal: true

module RailsMcp
  module Database
    class QueryBuilder
      class Error < StandardError; end

      ALLOWED_ORDER_DIRECTIONS = %w[ASC DESC].freeze

      def initialize(klass, conditions: {}, fields: [], limit: nil, offset: 0, order: nil)
        @klass      = klass
        @conditions = conditions.transform_keys(&:to_s)
        @fields     = Array(fields).map(&:to_s)
        @limit      = clamp_limit(limit)
        @offset     = offset.to_i
        @order      = order
      end

      def execute
        validate_conditions!
        validate_fields!
        validate_order!

        scope = @klass.where(@conditions)
        scope = scope.select(resolved_fields)
        scope = scope.limit(@limit)
        scope = scope.offset(@offset) if @offset > 0
        scope = scope.order(safe_order_clause) if @order

        scope.map { |record| serialize(record) }
      end

      private

      def column_names
        @column_names ||= begin
          schema = RailsMcp.schema_config
          cols = if schema
            auto = RailsMcp.configuration.default_fields.map(&:to_s) & @klass.column_names
            (schema.allowed_columns(@klass.name) + auto).uniq
          else
            @klass.column_names
          end
          cols.reject { |col| RailsMcp.configuration.column_denied?(col) }
        end
      end

      def resolved_fields
        return @fields unless @fields.empty?

        RailsMcp.configuration.default_fields.map(&:to_s) & column_names
      end

      def clamp_limit(limit)
        max = RailsMcp.configuration.max_limit
        return max if limit.nil?

        [limit.to_i, max].min.then { |n| n > 0 ? n : max }
      end

      def validate_conditions!
        unknown = @conditions.keys - column_names
        raise Error, "Unknown column(s) in conditions: #{unknown.join(", ")}" if unknown.any?
      end

      def validate_fields!
        unknown = @fields - column_names
        raise Error, "Unknown field(s): #{unknown.join(", ")}" if unknown.any?
      end

      def validate_order!
        return unless @order

        col, dir = @order.to_s.strip.split(/\s+/, 2)
        raise Error, "Unknown order column: #{col}" unless column_names.include?(col)

        if dir && !ALLOWED_ORDER_DIRECTIONS.include?(dir.upcase)
          raise Error, "Invalid order direction: #{dir}. Use ASC or DESC"
        end
      end

      def safe_order_clause
        col, dir = @order.to_s.strip.split(/\s+/, 2)
        dir = dir&.upcase == "DESC" ? "DESC" : "ASC"
        quoted_col = @klass.connection.quote_column_name(col)
        Arel.sql("#{quoted_col} #{dir}")
      end

      def serialize(record)
        resolved_fields.each_with_object({}) do |field, hash|
          hash[field] = record.public_send(field)
        end
      end
    end
  end
end
