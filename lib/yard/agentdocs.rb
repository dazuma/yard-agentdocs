# frozen_string_literal: true

require "yard"

require "yard/agentdocs/attribute"
require "yard/agentdocs/attribute_info"
require "yard/agentdocs/auxiliary_tags"
require "yard/agentdocs/builder"
require "yard/agentdocs/cross_referencing"
require "yard/agentdocs/docstring_summary"
require "yard/agentdocs/erb_with_trim_mode"
require "yard/agentdocs/example_tags"
require "yard/agentdocs/frontmatter"
require "yard/agentdocs/gem_builder"
require "yard/agentdocs/gem_cleaner"
require "yard/agentdocs/markdownify"
require "yard/agentdocs/member_listing"
require "yard/agentdocs/member_roster"
require "yard/agentdocs/method_signature"
require "yard/agentdocs/nodoc_filter"
require "yard/agentdocs/rdoc_to_markdown"
require "yard/agentdocs/text_layout"
require "yard/agentdocs/version"
require "yard/agentdocs/visibility_info"

##
# See https://yardoc.org for info on YARD itself.
#
module YARD
  ##
  # yard-agentdocs is a YARD plugin that renders Ruby API reference
  # documentation in a format designed for coding agents to look up
  # efficiently, rather than for human browsing.
  #
  module AgentDocs
  end
end
