# frozen_string_literal: true

module RailsMcp
  module Database
    class QueryBuilder
      class Error < StandardError; end

      ALLOWED_ORDER_DIRECTIONS = %w[ASC DESC].freeze
      SCALAR_TYPES = [String, Integer, Float, TrueClass, FalseClass, NilClass].freeze

      def initialize(klass, conditions: {}, fields: [], limit: nil, offset: 0, order: nil)
        @klass      = klass
        @conditions = conditions.transform_keys(&:to_s)
        @fields     = Array(fields).map(&:to_s)
        @limit      = clamp_limit(limit)
        @offset     = [offset.to_i, 0].max
        @order      = order
      end

      def execute
        validate_conditions!
        validate_fields!
        validate_order!
        validate_offset!

        scope = @klass.where(@conditions)
        scope = scope.select(resolved_fields.map { |f| @klass.arel_table[f] })
        scope = scope.limit(@limit)
        scope = scope.offset(@offset) if @offset.positive?
        scope = scope.order(safe_order_clause) if @order

        scope.map { |record| serialize(record) }
      end

      private

      def column_names
        @column_names ||= ColumnPolicy.allowed_for(@klass)
      end

      def resolved_fields
        return @fields unless @fields.empty?

        RailsMcp.configuration.default_fields.map(&:to_s) & column_names
      end

      def clamp_limit(limit)
        max = RailsMcp.configuration.max_limit
        return max if limit.nil?

        [limit.to_i, max].min.then { |n| n.positive? ? n : max }
      end

      def validate_conditions!
        unknown = @conditions.keys - column_names
        raise Error, "Unknown column(s) in conditions: #{unknown.join(", ")}" if unknown.any?

        invalid = @conditions.reject { |_, v| valid_condition_value?(v) }
        return unless invalid.any?

        raise Error,
              "Invalid condition value(s) for: #{invalid.keys.join(", ")} (scalars and arrays only)"
      end

      def validate_fields!
        unknown = @fields - column_names
        raise Error, "Unknown field(s): #{unknown.join(", ")}" if unknown.any?
      end

      def validate_offset!
        max = RailsMcp.configuration.max_offset
        raise Error, "Offset #{@offset} exceeds maximum allowed offset of #{max}" if @offset > max
      end

      def validate_order!
        return unless @order

        col, dir = @order.to_s.strip.split(/\s+/, 2)
        raise Error, "Unknown order column: #{col}" unless column_names.include?(col)

        return unless dir && !ALLOWED_ORDER_DIRECTIONS.include?(dir.upcase)

        raise Error, "Invalid order direction: #{dir}. Use ASC or DESC"
      end

      def safe_order_clause
        col, dir = @order.to_s.strip.split(/\s+/, 2)
        dir = dir&.upcase == "DESC" ? "DESC" : "ASC"
        quoted_col = @klass.connection.quote_column_name(col)
        Arel.sql("#{quoted_col} #{dir}")
      end

      def serialize(record)
        resolved_fields
          .select { |field| column_names.include?(field) }
          .reject { |field| RailsMcp.configuration.column_denied?(field) }
          .to_h { |field| [field, record.public_send(field)] }
      end

      def valid_condition_value?(value)
        if value.is_a?(Array)
          value.all? { |v| SCALAR_TYPES.any? { |t| v.is_a?(t) } }
        else
          SCALAR_TYPES.any? { |t| value.is_a?(t) }
        end
      end
    end
  end
end
