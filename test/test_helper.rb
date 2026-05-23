# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "minitest/autorun"
require "active_support/test_case"
require "action_dispatch/testing/integration"

# Load schema into the in-memory DB
ActiveRecord::Schema.verbose = false
load File.expand_path("dummy/db/schema.rb", __dir__)

# Stub connected_to so SQLite :reading role works in tests
module ActiveRecord
  class Base
    class << self
      alias _original_connected_to connected_to

      def connected_to(**_kwargs)
        yield
      end
    end
  end
end

class ActiveSupport::TestCase
  setup do
    RailsMcp.reset_configuration!
    RailsMcp::Server.reset!
  end

  teardown do
    User.delete_all
    Post.delete_all
  end

  # Build a valid Doorkeeper access token for request tests
  def create_access_token
    app = Doorkeeper::Application.create!(
      name: "test",
      redirect_uri: "urn:ietf:wg:oauth:2.0:oob",
      confidential: false
    )
    Doorkeeper::AccessToken.create!(application: app, expires_in: 3600)
  end
end
