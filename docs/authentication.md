# Authentication

activerecord-mcp uses [Doorkeeper](https://github.com/doorkeeper-gem/doorkeeper) for OAuth 2.1 server-side authentication with PKCE. Every request to the MCP endpoint requires a valid Bearer token.

## How it works

A Rack middleware (`RailsMcp::Auth::TokenValidator`) sits in front of the MCP transport. It validates the Bearer token against Doorkeeper before the request ever reaches the JSON-RPC layer. Invalid, expired, or revoked tokens are rejected with a `401` response — no tool code runs.

Two paths bypass the middleware:
- `OPTIONS` requests (CORS preflight)
- `/.well-known/` paths (OAuth discovery — must be public)

## Setup

### 1. Install Doorkeeper

```ruby
# Gemfile
gem "doorkeeper"
gem "activerecord-mcp"
```

```bash
bin/rails generate doorkeeper:install
bin/rails generate doorkeeper:migration
bin/rails db:migrate
```

### 2. Configure Doorkeeper with PKCE

```ruby
# config/initializers/doorkeeper.rb
Doorkeeper.configure do
  orm :active_record

  # PKCE S256 is required — activerecord-mcp warns at boot if this is missing
  pkce_code_challenge_methods %w[S256]

  resource_owner_authenticator do
    current_user || redirect_to(new_user_session_url)
  end
end
```

activerecord-mcp logs a warning at boot if PKCE S256 is not enabled. It does not raise — Doorkeeper config is owned by the host app.

### 3. Add routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  use_doorkeeper
  mount RailsMcp::Engine, at: "/mcp"
end
```

## Required scope

Every token must carry the `mcp` scope (configurable via `config.scope`). A valid, non-expired token that lacks the scope is rejected with `403 insufficient_scope` before any tool code runs. This prevents tokens issued to other parts of your app (e.g. a mobile API client) from being used to access the MCP endpoint.

To issue a token with the right scope, ensure your Doorkeeper config includes it:

```ruby
# config/initializers/doorkeeper.rb
Doorkeeper.configure do
  optional_scopes :mcp
  # ...
end
```

Then request or create tokens that include the `mcp` scope. To use a different scope name, or to disable the check entirely, see [`configuration.scope`](configuration.md#scope).

## Connecting Claude

Register the server with Claude Code using the `claude mcp add` command:

```bash
claude mcp add --transport http company-mcp https://your-app.com/mcp \
  --header "Authorization: Bearer $TOKEN"
```

Replace `company-mcp` with whatever name you want the server to appear as in Claude, and `$TOKEN` with your Bearer token. To persist the token across sessions, export it in your shell profile:

```bash
export COMPANY_MCP_TOKEN="eyJhbGc..."

claude mcp add --transport http company-mcp https://your-app.com/mcp \
  --header "Authorization: Bearer $COMPANY_MCP_TOKEN"
```

Use `--scope project` to share the server config with your whole team via `.mcp.json`:

```bash
claude mcp add --transport http company-mcp https://your-app.com/mcp \
  --header "Authorization: Bearer $COMPANY_MCP_TOKEN" \
  --scope project
```

Each developer supplies their own token via the environment variable; the URL and server name are committed.

## Connecting Codex

Add the server to `~/.codex/config.toml` (or `.codex/config.toml` in your project root for team-scoped config):

```toml
[mcp_servers.company-mcp]
url = "https://your-app.com/mcp"
bearer_token_env_var = "COMPANY_MCP_TOKEN"
```

`bearer_token_env_var` names the environment variable that holds the Bearer token — Codex reads it at runtime and sends it as the `Authorization` header. Export the variable in your shell profile:

```bash
export COMPANY_MCP_TOKEN="eyJhbGc..."
```

If you need to pass additional static headers alongside the token:

```toml
[mcp_servers.company-mcp]
url = "https://your-app.com/mcp"
bearer_token_env_var = "COMPANY_MCP_TOKEN"
http_headers = { "X-App-Env" = "production" }
```

## Making authenticated requests

Include the token in the `Authorization` header:

```
Authorization: Bearer <access_token>
```

Example:

```bash
curl -X POST https://your-app.com/mcp \
  -H "Authorization: Bearer eyJhbGc..." \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":1}'
```

## OAuth discovery

The endpoint `GET /mcp/.well-known/oauth-authorization-server` is public and returns standard OAuth 2.1 discovery metadata pointing to your Doorkeeper endpoints. MCP clients that support OAuth discovery can use this to auto-configure themselves.

```bash
curl https://your-app.com/mcp/.well-known/oauth-authorization-server
```

## Error responses

| Condition | Status | Body |
|-----------|--------|------|
| Missing `Authorization` header | `401` | `{"error":"invalid_token"}` |
| Token not found | `401` | `{"error":"invalid_token"}` |
| Token revoked | `401` | `{"error":"invalid_token"}` |
| Token expired | `401` | `{"error":"invalid_token"}` |
| Token lacks required scope | `403` | `{"error":"insufficient_scope"}` |

All `401` responses include a `WWW-Authenticate: Bearer realm="activerecord-mcp"` header.

## Creating tokens (development)

```ruby
# bin/rails console
app   = Doorkeeper::Application.create!(
  name:          "my-mcp-client",
  redirect_uri:  "urn:ietf:wg:oauth:2.0:oob",
  confidential:  false,
  scopes:        ""
)
token = Doorkeeper::AccessToken.create!(application: app, expires_in: 7200)
puts token.token
```
