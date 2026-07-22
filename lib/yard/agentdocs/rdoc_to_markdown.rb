# frozen_string_literal: true

require "rdoc/markup/to_markdown"

module YARD
  module AgentDocs
    ##
    # A `::RDoc::Markup::ToMarkdown` that never falls back to raw HTML for
    # styled inline text (`<tt>`/`<code>`, `<b>`/`<i>`/`<em>`, `<s>`/`<del>`,
    # and their `+word+`/`` `word` ``/`*word*`/`_word_` shorthand
    # equivalents). The stdlib converter takes that raw-HTML branch
    # whenever the styled content has any character outside plain word
    # characters/whitespace — routine in Ruby prose (`+valid?+`, `+save!+`,
    # `+Foo::Bar+`) — leaking literal `<code>...</code>`/`<strong>...
    # </strong>` etc. into what's supposed to be pure Markdown. See
    # "`RDoc::Markup::ToMarkdown` raw-HTML leaks" under "Decisions" in
    # devdocs/DESIGN.md for the full survey.
    #
    # Only overrides {#add_tag}, the single choke point `handle_BOLD`/
    # `handle_EM`/`handle_STRIKE`/`handle_TT` all funnel single-string
    # content through — content spanning multiple inline nodes (nested
    # styled markup, e.g. `<b>foo *bar* baz</b>`) still takes the upstream
    # raw-HTML path via `handle_tag`'s other branch; that's the
    # not-yet-designed remainder of the checklist item this class partially
    # settles.
    #
    # Deliberately does not touch `accept_verbatim`: a verbatim/code-example
    # block's content is copied straight through by the upstream class
    # without ever calling {#add_tag}, so literal `<code>`/`<tt>` text a
    # docstring author wrote on purpose (e.g. inside an indented code
    # sample) is unaffected by this override.
    #
    class RDocToMarkdown < ::RDoc::Markup::ToMarkdown
      ##
      # @param _tag [String] the HTML tag name (unused — the raw-HTML
      #   branch this override removes is the only caller that needed it)
      # @param simple_tag [String] the Markdown delimiter (e.g. `` "`" ``,
      #   `"**"`, `"*"`, `"~~"`)
      # @param content [String] the already-converted inline text to wrap
      # @return [void]
      #
      def add_tag(_tag, simple_tag, content)
        emit_inline("#{simple_tag}#{content}#{simple_tag}")
      end
    end
  end
end
