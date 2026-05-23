# frozen_string_literal: true

module RailsMcp
  class WellKnownController < ActionController::API
    def oauth_metadata
      issuer = "#{request.scheme}://#{request.host_with_port}"
      render json: {
        issuer: issuer,
        authorization_endpoint: "#{issuer}/oauth/authorize",
        token_endpoint: "#{issuer}/oauth/token",
        response_types_supported: ["code"],
        grant_types_supported: ["authorization_code"],
        code_challenge_methods_supported: ["S256"],
        token_endpoint_auth_methods_supported: ["none"]
      }
    end
  end
end
