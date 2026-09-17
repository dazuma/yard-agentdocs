# frozen_string_literal: true

lib = ::File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "yard/agentdocs/version"

::Gem::Specification.new do |spec|
  spec.name = "yard-agentdocs"
  spec.version = ::YARD::AgentDocs::VERSION
  spec.authors = ["Daniel Azuma"]
  spec.email = ["dazuma@gmail.com"]

  spec.summary = "A YARD plugin that generates agent-friendly reference documentation."
  spec.description =
    "A YARD template plugin that renders Ruby API reference documentation in a format" \
    " designed for coding agents to look up efficiently, minimizing the tokens needed" \
    " to find a method's documentation."
  spec.license = "MIT"
  spec.homepage = "https://github.com/dazuma/yard-agentdocs"

  # `templates/**/*` has to be listed explicitly — it is not swept in by the
  # `lib/**/*.rb` glob, and a built gem otherwise ships with no templates at
  # all, silently. The same applies to any other non-`lib/` directory.
  spec.files = ::Dir.glob("lib/**/*.rb") +
               ::Dir.glob("templates/**/*") +
               # FNM_DOTMATCH so the tools' `.toys.rb` files are included.
               ::Dir.glob("toys/**/*", ::File::FNM_DOTMATCH)
                    .reject { |path| ::File.basename(path).match?(/\A\.\.?\z/) } +
               (::Dir.glob("*.md") - ["CLAUDE.md", "AGENTS.md", "CONTEXT.md"]) +
               ::Dir.glob("skills/**/*") +
               [".yardopts"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rdoc", ">= 6.0"
  spec.add_dependency "simple_xdg", "~> 0.1"
  spec.add_dependency "yard", "~> 0.9"
  spec.required_ruby_version = ">= 3.4"

  spec.metadata["bug_tracker_uri"] = "https://github.com/dazuma/yard-agentdocs/issues"
  spec.metadata["changelog_uri"] = "https://rubydoc.info/gems/yard-agentdocs/#{::YARD::AgentDocs::VERSION}/file/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/yard-agentdocs/#{::YARD::AgentDocs::VERSION}"
  spec.metadata["homepage_uri"] = "https://github.com/dazuma/yard-agentdocs"
end
