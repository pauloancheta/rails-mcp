# frozen_string_literal: true

require "test_helper"

class QueryRecordsToolTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Alice", email: "alice@example.com", age: 30, active: true)
    User.create!(name: "Bob", email: "bob@example.com", age: 25, active: false)
  end

  test "returns default fields" do
    response = call(model: "User")
    records  = JSON.parse(response.content.first[:text])
    assert records.first.key?("id")
    assert records.first.key?("created_at")
    refute records.first.key?("name")
  end

  test "returns specified fields" do
    response = call(model: "User", fields: %w[name email])
    records  = JSON.parse(response.content.first[:text])
    assert records.first.key?("name")
    assert records.first.key?("email")
    refute records.first.key?("id")
  end

  test "filters by conditions" do
    response = call(model: "User", conditions: { "active" => true }, fields: ["name"])
    records  = JSON.parse(response.content.first[:text])
    assert_equal 1, records.length
    assert_equal "Alice", records.first["name"]
  end

  test "raises on unknown model" do
    assert_raises(RailsMcp::Database::ModelResolver::UnknownModel) do
      call(model: "Ghost")
    end
  end

  test "raises on SQL injection in order" do
    assert_raises(RailsMcp::Database::QueryBuilder::Error) do
      call(model: "User", order: "1=1; DROP TABLE users")
    end
  end

  private

  def call(**args)
    RailsMcp::Tools::QueryRecords.call(server_context: {}, **args)
  end
end
