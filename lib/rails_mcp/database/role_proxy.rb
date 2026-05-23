# frozen_string_literal: true

module RailsMcp
  module Database
    module RoleProxy
      def self.with_role(&)
        ActiveRecord::Base.connected_to(role: RailsMcp.configuration.database_role, &)
      end
    end
  end
end
