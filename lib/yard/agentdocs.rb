# frozen_string_literal: true

require "yard"

require "yard/agentdocs/attribute"
require "yard/agentdocs/attribute_info"
require "yard/agentdocs/auxiliary_tags"
require "yard/agentdocs/cross_referencing"
require "yard/agentdocs/docstring_summary"
require "yard/agentdocs/erb_with_trim_mode"
require "yard/agentdocs/example_tags"
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
  # This gem is under initial development; see CLAUDE.md for the current
  # design status. The `agentdocs` output format is implemented as a set of
  # YARD templates under `templates/`, registered by `lib/yard-agentdocs.rb`;
  # invoke it with `yard doc -f agentdocs`.
  #
  module AgentDocs
  end
end
