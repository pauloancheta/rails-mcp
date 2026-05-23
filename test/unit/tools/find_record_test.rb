# frozen_string_literal: true

require "test_helper"

class FindRecordToolTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Alice", email: "alice@example.com")
  end

  test "finds record by id with default fields" do
    response = call(model: "User", id: @user.id)
    result   = JSON.parse(response.content.first[:text])
    assert_equal @user.id, result["id"]
    refute result.key?("name")
  end

  test "finds record with requested fields" do
    response = call(model: "User", id: @user.id, fields: %w[name email])
    result   = JSON.parse(response.content.first[:text])
    assert_equal "Alice",               result["name"]
    assert_equal "alice@example.com",   result["email"]
  end

  test "raises when record not found" do
    assert_raises(RailsMcp::Database::ModelResolver::UnknownModel) do
      call(model: "User", id: 999_999)
    end
  end

  test "raises on unknown field" do
    assert_raises(RailsMcp::Database::QueryBuilder::Error) do
      call(model: "User", id: @user.id, fields: ["nonexistent"])
    end
  end

  private

  def call(**args)
    RailsMcp::Tools::FindRecord.call(server_context: {}, **args)
  end
end
