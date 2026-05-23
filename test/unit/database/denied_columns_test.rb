# frozen_string_literal: true

require "test_helper"

class DeniedColumnsTest < ActiveSupport::TestCase
  setup do
    User.create!(name: "Alice", email: "alice@example.com", age: 30)
  end

  teardown do
    User.delete_all
  end

  # --- exact string match ---

  test "denied column by exact string cannot be used in fields" do
    RailsMcp.configuration.denied_columns = ["age"]
    err = assert_raises(RailsMcp::Database::QueryBuilder::Error) do
      build(User, fields: ["age"]).execute
    end
    assert_match "Unknown field(s)", err.message
  end

  test "denied column by exact string cannot be used in conditions" do
    RailsMcp.configuration.denied_columns = ["age"]
    err = assert_raises(RailsMcp::Database::QueryBuilder::Error) do
      build(User, conditions: { "age" => 30 }).execute
    end
    assert_match "Unknown column(s) in conditions", err.message
  end

  test "denied column by exact string cannot be used in order" do
    RailsMcp.configuration.denied_columns = ["age"]
    err = assert_raises(RailsMcp::Database::QueryBuilder::Error) do
      build(User, order: "age DESC").execute
    end
    assert_match "Unknown order column", err.message
  end

  test "denied column does not appear in default results" do
    RailsMcp.configuration.denied_columns = ["age"]
    RailsMcp.configuration.default_fields = %i[id age created_at]
    results = build(User).execute
    refute results.first.key?("age")
    assert results.first.key?("id")
  end

  # --- regex match ---

  test "denied column by regex cannot be used in fields" do
    RailsMcp.configuration.denied_columns = [/password/i]
    err = assert_raises(RailsMcp::Database::QueryBuilder::Error) do
      build(User, fields: ["password_digest"]).execute
    end
    assert_match "Unknown field(s)", err.message
  end

  test "regex matches multiple columns" do
    RailsMcp.configuration.denied_columns = [/\Aactive\z/]
    err = assert_raises(RailsMcp::Database::QueryBuilder::Error) do
      build(User, fields: ["active"]).execute
    end
    assert_match "Unknown field(s)", err.message
    # other columns still work
    results = build(User, fields: ["name"]).execute
    assert results.first.key?("name")
  end

  # --- mix of strings and regexes ---

  test "accepts a mix of strings and regexes" do
    RailsMcp.configuration.denied_columns = ["age", /email/i]
    err = assert_raises(RailsMcp::Database::QueryBuilder::Error) do
      build(User, fields: ["age"]).execute
    end
    assert_match "Unknown field(s)", err.message

    err = assert_raises(RailsMcp::Database::QueryBuilder::Error) do
      build(User, fields: ["email"]).execute
    end
    assert_match "Unknown field(s)", err.message

    # non-denied columns still work
    results = build(User, fields: ["name"]).execute
    assert results.first.key?("name")
  end

  # --- interaction with schema_file ---

  test "denied_columns applies on top of schema_file" do
    fixture = File.expand_path("../../fixtures/rails_mcp.yml", __dir__)
    RailsMcp.configure do |c|
      c.schema_file    = fixture
      c.denied_columns = ["email"]  # email is in the schema but denied here
    end

    err = assert_raises(RailsMcp::Database::QueryBuilder::Error) do
      build(User, fields: ["email"]).execute
    end
    assert_match "Unknown field(s)", err.message

    # name is still accessible
    results = build(User, fields: ["name"]).execute
    assert results.first.key?("name")
  end

  # --- non-denied columns are unaffected ---

  test "non-denied columns are still accessible" do
    RailsMcp.configuration.denied_columns = ["age"]
    results = build(User, fields: ["name", "email"]).execute
    assert results.first.key?("name")
    assert results.first.key?("email")
  end

  private

  def build(klass, **opts)
    RailsMcp::Database::QueryBuilder.new(klass, **opts)
  end
end
