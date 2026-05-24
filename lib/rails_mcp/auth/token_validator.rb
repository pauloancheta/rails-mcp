# frozen_string_literal: true

module RailsMcp
  module Auth
    class TokenValidator
      WELL_KNOWN_PREFIX = "/.well-known/"

      def initialize(app)
        @app = app
      end

      def call(env)
        request = Rack::Request.new(env)

        # CORS preflight and public discovery endpoints bypass auth
        return @app.call(env) if request.options?
        return @app.call(env) if request.path.start_with?(WELL_KNOWN_PREFIX)

        token_string = extract_bearer_token(env)
        return log_and_reject(request, :unauthorized, "Bearer token required") if token_string.nil?

        token = Doorkeeper::AccessToken.by_token(token_string)
        if token.nil? || token.revoked? || token.expired?
          return log_and_reject(request, :unauthorized, "Invalid or expired token")
        end

        required = RailsMcp.configuration.scope
        if required && !required.empty? && !token.scopes.include?(required)
          return log_and_reject(request, :insufficient_scope, required)
        end

        env["rails_mcp.access_token"] = token
        @app.call(env)
      end

      private

      def extract_bearer_token(env)
        auth = env["HTTP_AUTHORIZATION"]
        return nil unless auth&.start_with?("Bearer ")

        auth.delete_prefix("Bearer ").strip
      end

      def log_and_reject(request, type, detail)
        Rails.logger.warn "[activerecord-mcp] Auth rejected #{request.request_method} #{request.path} " \
                          "ip=#{request.ip} reason=#{type} detail=#{detail.inspect}"
        type == :insufficient_scope ? insufficient_scope(detail) : unauthorized(detail)
      end

      def unauthorized(message)
        body = { error: "invalid_token", error_description: message }.to_json
        [
          401,
          { "Content-Type" => "application/json", "WWW-Authenticate" => 'Bearer realm="activerecord-mcp"' },
          [body]
        ]
      end

      def insufficient_scope(scope)
        body = { error: "insufficient_scope", error_description: "Token missing required scope: #{scope}" }.to_json
        [
          403,
          {
            "Content-Type" => "application/json",
            "WWW-Authenticate" => "Bearer realm=\"activerecord-mcp\", error=\"insufficient_scope\", scope=\"#{scope}\""
          },
          [body]
        ]
      end
    end
  end
end
