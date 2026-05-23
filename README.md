# rails-mcp

A Rails Engine that adds an [MCP (Model Context Protocol)](https://modelcontextprotocol.io) server to your app. Built on the [official MCP Ruby SDK](https://github.com/modelcontextprotocol/ruby-sdk), it exposes safe, role-aware ActiveRecord query tools over **Streamable HTTP** — no SSE, no standalone process, no extra memory footprint.

Because it mounts as a Rails Engine, MCP requests share Puma's thread pool and ActiveRecord connection pool with the rest of your app.

## Why not fast-mcp?

fast-mcp uses SSE transport, which holds a Puma thread open for the lifetime of each client connection. With 5 Puma threads and 5 MCP clients connected, your app is saturated. SSE was [deprecated in the MCP spec](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports) in March 2025 in favour of Streamable HTTP, which uses normal short-lived POST requests.

## Features

- **Streamable HTTP transport** — standard POST requests, no persistent connections
- **5 built-in database tools** — query, find, count, list, and describe AR models
- **No raw SQL** — all queries go through hash conditions validated against actual column names
- **Configurable database role** — defaults to `:reading`, works with any named role (`connected_to`)
- **Default field filtering** — returns only `id`, `created_at`, `updated_at` unless more fields are requested
- **Model allowlist / denylist** — restrict which models are accessible
- **OAuth 2.1 + PKCE** — server-side auth via [Doorkeeper](https://github.com/doorkeeper-gem/doorkeeper)
- **Custom tool DSL** — register your own MCP tools alongside the built-ins

## Installation

Add to your Gemfile:

```ruby
gem "rails-mcp"
gem "doorkeeper"
```

## Setup

**1. Configure Doorkeeper** (`config/initializers/doorkeeper.rb`):

```ruby
Doorkeeper.configure do
  orm :active_record
  pkce_code_challenge_methods %w[S256]
  # ... rest of your Doorkeeper config
end
```

Run Doorkeeper's migrations if you haven't already:

```bash
bin/rails generate doorkeeper:install
bin/rails generate doorkeeper:migration
bin/rails db:migrate
```

**2. Mount the engine** (`config/routes.rb`):

```ruby
Rails.application.routes.draw do
  use_doorkeeper
  mount RailsMcp::Engine, at: "/mcp"
end
```

**3. Configure rails-mcp** (optional, `config/initializers/rails_mcp.rb`):

```ruby
RailsMcp.configure do |config|
  config.database_role  = :reading   # default — any named role works
  config.default_fields = [:id, :created_at, :updated_at]  # default
  config.allowed_models = %w[User Post Order]  # empty = all models
  config.denied_models   = %w[AdminUser]
  config.denied_columns  = ["password_digest", "encrypted_password", /token/i, /secret/i]
  config.max_limit       = 100        # max records per query

  # Optional: point to a YAML file that defines per-model column allowlists.
  # When set, this takes precedence over allowed_models / denied_models.
  config.schema_file = Rails.root.join("config/rails_mcp.yml")
end
```

## Schema File

For fine-grained control, define exactly which models and columns the MCP can access in a YAML file:

```yaml
# config/rails_mcp.yml
User:
  - id
  - name
  - email
  - created_at
  - updated_at
Post:
  - id
  - title
  - created_at
  - updated_at
```

## Denying Columns

`denied_columns` accepts an array of exact strings and/or regexes. Matching columns become completely invisible — they cannot be returned, used in `conditions`, or used in `order`, regardless of whether a `schema_file` is set.

```ruby
RailsMcp.configure do |config|
  config.denied_columns = [
    "password_digest",
    "encrypted_password",
    /token/i,
    /secret/i,
    /api_key/i
  ]
end
```

`denied_columns` is applied last, after schema and model column resolution, so it always wins.

## Schema File

When `schema_file` is configured:

- Only models listed in the file are accessible — `allowed_models` and `denied_models` are ignored
- Each model's column list is the only set of columns that can appear in `fields`, `conditions`, or `order`
- Requesting a column not in the list raises an error and returns no data

## Built-in Database Tools

All tools return only `id`, `created_at`, and `updated_at` by default. Pass `fields` to get more columns.

### `list_models`
Lists all accessible ActiveRecord model names.

```json
{ "name": "list_models", "arguments": {} }
```

### `describe_model`
Returns columns, types, and associations for a model.

```json
{ "name": "describe_model", "arguments": { "model": "User" } }
```

### `query_records`
Queries records with hash conditions. No raw SQL accepted.

```json
{
  "name": "query_records",
  "arguments": {
    "model": "User",
    "conditions": { "active": true },
    "fields": ["id", "name", "email"],
    "limit": 10,
    "offset": 0,
    "order": "created_at DESC"
  }
}
```

### `find_record`
Finds a single record by primary key.

```json
{
  "name": "find_record",
  "arguments": { "model": "User", "id": 42, "fields": ["name", "email"] }
}
```

### `count_records`
Counts records matching hash conditions.

```json
{
  "name": "count_records",
  "arguments": { "model": "User", "conditions": { "active": true } }
}
```

## Custom Tools

Register additional tools in an initializer **before the first request**:

```ruby
RailsMcp::Server.tool("business_summary") do
  description "Return a summary of today's orders"
  parameter :date, type: :string, description: "ISO 8601 date", required: true

  call do |params, _server_context|
    date   = Date.parse(params[:date])
    orders = Order.where(created_at: date.all_day)
    { count: orders.count, total: orders.sum(:amount_cents) }
  end
end
```

## Authentication

Every request to `/mcp` must include a valid Doorkeeper Bearer token:

```
Authorization: Bearer <access_token>
```

The `/.well-known/oauth-authorization-server` endpoint is public and returns OAuth 2.1 discovery metadata pointing to your Doorkeeper endpoints.

## Architecture

```
POST /mcp
  └─> TokenValidator (Rack middleware — validates Doorkeeper Bearer token)
        └─> MCP::Server::Transports::StreamableHTTPTransport (official SDK)
              └─> MCP::Server (JSON-RPC dispatch)
                    └─> RailsMcp built-in tools
                          └─> RoleProxy → QueryBuilder → ActiveRecord
```

## Development

```bash
bin/setup          # install dependencies
bundle exec rake test    # run tests (45 tests, 89 assertions)
```

## Contributing

Bug reports and pull requests welcome at https://github.com/pauloancheta/rails-mcp.
