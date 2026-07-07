# frozen_string_literal: true

lib = ::File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "yard/agents/version"

::Gem::Specification.new do |spec|
  spec.name = "yard-agents"
  spec.version = ::YARD::Agents::VERSION
  spec.authors = ["Daniel Azuma"]
  spec.email = ["dazuma@gmail.com"]

  spec.summary = "A YARD plugin that generates agent-friendly reference documentation."
  spec.description =
    "A YARD template plugin that renders Ruby API reference documentation in a format" \
    " designed for coding agents to look up efficiently, minimizing the tokens needed" \
    " to find a method's documentation."
  spec.license = "MIT"
  spec.homepage = "https://github.com/dazuma/yard-agents"

  spec.files = ::Dir.glob("lib/**/*.rb") +
               (::Dir.glob("*.md") - ["CLAUDE.md", "AGENTS.md"]) +
               [".yardopts"]
  spec.require_paths = ["lib"]

  spec.add_dependency "yard", "~> 0.9"
  spec.required_ruby_version = ">= 3.4"

  spec.metadata["bug_tracker_uri"] = "https://github.com/dazuma/yard-agents/issues"
  spec.metadata["changelog_uri"] = "https://rubydoc.info/gems/yard-agents/#{::YARD::Agents::VERSION}/file/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/yard-agents/#{::YARD::Agents::VERSION}"
  spec.metadata["homepage_uri"] = "https://github.com/dazuma/yard-agents"
end
