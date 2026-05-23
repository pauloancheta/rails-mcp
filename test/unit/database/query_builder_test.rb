# frozen_string_literal: true

require "test_helper"

class QueryBuilderTest < ActiveSupport::TestCase
  setup do
    User.create!(name: "Alice", email: "alice@example.com", age: 30, active: true)
    User.create!(name: "Bob",   email: "bob@example.com",   age: 25, active: false)
  end

  test "returns default fields when none specified" do
    results = build(User).execute
    assert_equal %w[id created_at updated_at].sort, results.first.keys.sort
  end

  test "returns requested fields" do
    results = build(User, fields: %w[name email]).execute
    assert_equal %w[email name], results.first.keys.sort
  end

  test "filters by conditions" do
    results = build(User, conditions: { "active" => true }, fields: ["name"]).execute
    assert_equal 1, results.length
    assert_equal "Alice", results.first["name"]
  end

  test "respects limit" do
    results = build(User, limit: 1).execute
    assert_equal 1, results.length
  end

  test "caps limit at max_limit" do
    RailsMcp.configuration.max_limit = 1
    results = build(User, limit: 999).execute
    assert_equal 1, results.length
  end

  test "respects offset" do
    all    = build(User, fields: ["name"], limit: 10).execute
    offset = build(User, fields: ["name"], limit: 10, offset: 1).execute
    assert_equal all.length - 1, offset.length
  end

  test "orders results" do
    results = build(User, fields: ["name"], order: "name ASC").execute
    assert_equal "Alice", results.first["name"]

    results = build(User, fields: ["name"], order: "name DESC").execute
    assert_equal "Bob", results.first["name"]
  end

  test "raises on unknown condition column" do
    err = assert_raises(RailsMcp::Database::QueryBuilder::Error) do
      build(User, conditions: { "nonexistent" => 1 }).execute
    end
    assert_match "Unknown column(s) in conditions", err.message
  end

  test "raises on unknown field" do
    err = assert_raises(RailsMcp::Database::QueryBuilder::Error) do
      build(User, fields: ["nonexistent"]).execute
    end
    assert_match "Unknown field(s)", err.message
  end

  test "raises on unknown order column" do
    err = assert_raises(RailsMcp::Database::QueryBuilder::Error) do
      build(User, order: "nonexistent DESC").execute
    end
    assert_match "Unknown order column", err.message
  end

  test "raises on invalid order direction" do
    err = assert_raises(RailsMcp::Database::QueryBuilder::Error) do
      build(User, order: "name DROPTABLE").execute
    end
    assert_match "Invalid order direction", err.message
  end

  test "SQL injection in order column is rejected" do
    err = assert_raises(RailsMcp::Database::QueryBuilder::Error) do
      build(User, order: "name; DROP TABLE users").execute
    end
    # "name;" is not a valid column name, so the column check fires first
    assert_match(/Unknown order column/, err.message)
  end

  test "hash value in conditions is rejected" do
    err = assert_raises(RailsMcp::Database::QueryBuilder::Error) do
      build(User, conditions: { "name" => { "starts_with" => "Al" } }).execute
    end
    assert_match "Invalid condition value(s)", err.message
  end

  test "array of scalars in conditions is accepted" do
    results = build(User, conditions: { "name" => %w[Alice Bob] }, fields: ["name"]).execute
    assert_equal 2, results.length
  end

  test "raises when offset exceeds max_offset" do
    RailsMcp.configuration.max_offset = 500
    err = assert_raises(RailsMcp::Database::QueryBuilder::Error) do
      build(User, offset: 501).execute
    end
    assert_match "exceeds maximum allowed offset", err.message
    assert_match "500", err.message
  end

  test "offset at exactly max_offset is accepted" do
    RailsMcp.configuration.max_offset = 500
    assert_nothing_raised { build(User, offset: 500).execute }
  end

  test "negative offset is treated as zero" do
    results_zero = build(User, fields: ["name"]).execute
    results_negative = build(User, fields: ["name"], offset: -10).execute
    assert_equal results_zero, results_negative
  end

  test "array containing hash in conditions is rejected" do
    err = assert_raises(RailsMcp::Database::QueryBuilder::Error) do
      build(User, conditions: { "name" => [{ "starts_with" => "Al" }] }).execute
    end
    assert_match "Invalid condition value(s)", err.message
  end

  private

  def build(klass, **opts)
    RailsMcp::Database::QueryBuilder.new(klass, **opts)
  end
end
