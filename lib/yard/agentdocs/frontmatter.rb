# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # Shared by the `module`/`fulldoc` `agentdocs` templates: quoting
    # free-form text for use as a YAML frontmatter scalar value.
    #
    module Frontmatter
      ##
      # Double-quotes +text+ for a YAML `key: value` line, escaping `\`/`"`.
      # Never left unquoted, even when +text+ happens to be safe as-is: an
      # unquoted plain YAML scalar breaks if the text starts with a
      # Markdown/YAML indicator character (`` ` ``, `-`, `*`, …) or contains
      # `": "`, and +text+ here is always free-form (a docstring summary, or
      # a `# @title` comment), never a guaranteed-safe identifier.
      #
      # @param text [String]
      # @return [String]
      #
      def yaml_quote(text)
        escaped = text.gsub("\\", "\\\\\\\\").gsub('"', '\\"')
        %("#{escaped}")
      end
    end
  end
end
