# activerecord-mcp

[![CI](https://github.com/pauloancheta/activerecord-mcp/actions/workflows/main.yml/badge.svg)](https://github.com/pauloancheta/activerecord-mcp/actions/workflows/main.yml)

The read-only MCP server Rails developers have been looking for.

Drop it into any Rails app and your AI tools can introspect your ActiveRecord models and query your database instantly — no standalone process, no raw SQL, no credentials handed to a client. By default every query runs against a read-only database role, so production data stays safe. If you need writes, swap in any role your app already has.

Built on the [official MCP Ruby SDK](https://github.com/modelcontextprotocol/ruby-sdk) and mounted as a Rails Engine, it shares Puma's thread pool and your existing connection pool. Nothing extra to run.

## Why activerecord-mcp

- **Read-only by default** — queries run against a named database role (`:reading`); your write replica or primary is never touched unless you configure it
- **No raw SQL** — all queries go through hash conditions validated against actual column names; no string interpolation reaches the database
- **Fine-grained access control** — allowlist models, denylist columns by exact name or regex, or define a per-model column allowlist in a YAML file
- **OAuth 2.1 + PKCE** — every request requires a scoped Bearer token via [Doorkeeper](https://github.com/doorkeeper-gem/doorkeeper); tokens from other clients are rejected at the middleware layer
- **Zero extra infrastructure** — mounts as a Rails Engine; shares Puma threads and ActiveRecord connections with the rest of your app
- **Extensible** — register custom tools alongside the built-ins using a simple DSL

## Table of contents

- [Installation](#installation)
- [Basic setup](#basic-setup)
- [Quick example](#quick-example)
- [Documentation](#documentation)

## Installation

Add to your Gemfile:

```ruby
gem "activerecord-mcp"
gem "doorkeeper"
```

```bash
bundle install
bin/rails generate doorkeeper:install
bin/rails generate doorkeeper:migration
bin/rails db:migrate
```

## Basic setup

**1. Configure Doorkeeper** (`config/initializers/doorkeeper.rb`):

```ruby
Doorkeeper.configure do
  orm :active_record
  pkce_code_challenge_methods %w[S256]

  resource_owner_authenticator do
    current_user || redirect_to(new_user_session_url)
  end
end
```

**2. Mount the engine** (`config/routes.rb`):

```ruby
Rails.application.routes.draw do
  use_doorkeeper
  mount RailsMcp::Engine, at: "/mcp"
end
```

**3. Generate the initializer:**

```bash
bin/rails generate rails_mcp:install
```

This creates `config/initializers/rails_mcp.rb` with every option documented and commented out. Edit it to restrict access:


```ruby
RailsMcp.configure do |config|
  config.allowed_models = %w[User Post Order]
  config.denied_columns = ["password_digest", /token/i, /secret/i]
end
```

That's it — the five built-in query tools are live at `/mcp`.

## Quick example

```bash
# Get a Bearer token (see docs/authentication.md)
TOKEN="eyJhbGc..."

# Connect Claude Code
claude mcp add --transport http company-mcp https://your-app.com/mcp \
  --header "Authorization: Bearer $TOKEN"

# Connect Codex — add to ~/.codex/config.toml
# [mcp_servers.company-mcp]
# url = "https://your-app.com/mcp"
# bearer_token_env_var = "TOKEN"
```

That's it — Claude or Codex now has access to your Rails models. You can also hit the endpoint directly:

```bash
# List accessible models
curl -X POST https://your-app.com/mcp \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"list_models","arguments":{}},"id":1}'

# Query records
curl -X POST https://your-app.com/mcp \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "query_records",
      "arguments": {
        "model": "User",
        "conditions": { "active": true },
        "fields": ["id", "name", "email"],
        "limit": 10
      }
    },
    "id": 2
  }'
```

## Documentation

| Topic | Description |
|-------|-------------|
| [Authentication](docs/authentication.md) | OAuth 2.1 + PKCE setup, Bearer tokens, discovery endpoint |
| [Querying](docs/querying.md) | All five built-in tools with full argument reference |
| [Configuration](docs/configuration.md) | All config options with defaults and explanations |
| [Advanced usage](docs/advanced.md) | YAML model allowlist, explicit column deny, custom tools DSL |

## Development

```bash
bundle install
bundle exec rake test
```

Bug reports and pull requests welcome at https://github.com/pauloancheta/activerecord-mcp.
