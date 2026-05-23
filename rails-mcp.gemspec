# frozen_string_literal: true

require_relative "lib/rails_mcp/version"

Gem::Specification.new do |spec|
  spec.name = "rails-mcp"
  spec.version = RailsMcp::VERSION
  spec.authors = ["Paulo Ancheta"]
  spec.email = ["paulo.ancheta@gmail.com"]

  spec.summary = "MCP server for Rails apps — safe, role-aware database query tools over Streamable HTTP"
  spec.description = "A Rails Engine that implements a Model Context Protocol (MCP) server using " \
                     "HTTP-only Streamable HTTP transport. Provides built-in ActiveRecord query tools " \
                     "with configurable database roles, field filtering, and OAuth 2.1 + PKCE auth via Doorkeeper."
  spec.homepage = "https://github.com/pauloancheta/rails-mcp"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ spec/ .git .github appveyor Gemfile])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "doorkeeper", "~> 5.6"
  spec.add_dependency "mcp"
  spec.add_dependency "rails", ">= 7.0"
end
