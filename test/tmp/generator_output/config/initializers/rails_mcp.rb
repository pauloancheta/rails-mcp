# frozen_string_literal: true

RailsMcp.configure do |config|
  # The database role used for every query.
  # Queries run via ActiveRecord's connected_to(role:), so this maps directly
  # to a role defined in your database.yml. The default :reading role works
  # out of the box with Rails' standard replica setup. Set to :writing if
  # your app uses a single database with no named roles.
  #
  # config.database_role = :reading

  # Columns returned when no fields are specified in a tool call.
  # These are also automatically included when a schema_file is configured,
  # even if the file omits them.
  #
  # config.default_fields = [:id, :created_at, :updated_at]

  # Allowlist of model names the MCP can access.
  # When non-empty, any model not in this list returns an error.
  # Ignored when schema_file is set — the file's model list takes precedence.
  #
  # config.allowed_models = %w[User Post Order]

  # Denylist of model names that are never accessible, regardless of allowed_models.
  # Ignored when schema_file is set.
  #
  # config.denied_models = %w[AdminUser AuditLog]

  # Columns that are completely invisible across all models and all tools.
  # Accepts exact strings and/or regexes. Matching columns cannot be returned,
  # used in conditions, or used in order — even if they appear in schema_file.
  # Applied as the final layer, so it always wins over every other config.
  #
  # config.denied_columns = [
  #   "password_digest",
  #   "encrypted_password",
  #   /token/i,
  #   /secret/i,
  #   /api_key/i,
  # ]

  # Maximum number of records a single query_records call can return.
  # Client-supplied limit values are silently capped to this. Nil or zero
  # limits also resolve to this value.
  #
  # config.max_limit = 100

  # Maximum offset value accepted by query_records.
  # Unlike max_limit, exceeding this raises an error rather than silently
  # clamping — a clamped offset would return the wrong page without any
  # indication to the caller.
  #
  # config.max_offset = 10_000

  # Path to a YAML file that defines exactly which models and columns are
  # accessible. When set, allowed_models and denied_models are ignored —
  # the file's model list is the authoritative allowlist. id, created_at,
  # and updated_at are still auto-included from default_fields even if
  # omitted from the file. denied_columns still applies on top.
  #
  # config.schema_file = Rails.root.join("config/rails_mcp.yml")

  # OAuth scope that every Bearer token must include. Tokens that are
  # otherwise valid (not expired, not revoked) but lack this scope are
  # rejected with 403 insufficient_scope. Set to nil to disable the check.
  # Your Doorkeeper config must declare the same scope via optional_scopes.
  #
  # config.scope = "mcp"
end
