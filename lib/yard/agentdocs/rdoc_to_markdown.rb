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
    # docs/dev/DESIGN.md for the full survey.
    #
    # Overrides {#add_tag} (the single choke point `handle_BOLD`/
    # `handle_EM`/`handle_STRIKE`/`handle_TT` funnel single-string content
    # through) and {#handle_tag} (their shared multi-node/nested-content
    # path — e.g. `<b>foo *bar* baz</b>`), so neither ever takes the
    # upstream raw-HTML branch. `<tt>`/`<code>` never reach `handle_tag`'s
    # multi-node branch in the first place: RDoc's own parser captures
    # their content as one literal string, never nested nodes, so a
    # look-alike like `<tt>foo <b>bar</b> baz</tt>` was already correct
    # before this class existed — {#add_tag} alone covers it. Recursively
    # wrapping nested content in the same Markdown delimiter (rather than
    # flattening it) is safe even when the same delimiter repeats back to
    # back (e.g. `**foo **bar** baz**`): verified against a real CommonMark
    # parser (`commonmarker`) that this parses as nested `<strong>`, not a
    # prematurely-closed span.
    #
    # Deliberately does not touch `accept_verbatim`: a verbatim/code-example
    # block's content is copied straight through by the upstream class
    # without ever calling {#add_tag}/{#handle_tag}, so literal `<code>`/
    # `<tt>` text a docstring author wrote on purpose (e.g. inside an
    # indented code sample) is unaffected by this override.
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

      ##
      # @param nodes [Array<String, Hash>] the tag's inline child nodes —
      #   a single plain string is handled by delegating to the upstream
      #   implementation (which itself now calls the overridden
      #   {#add_tag}); anything else (multiple nodes, or none, as in an
      #   empty tag) wraps the recursively-converted content in
      #   +simple_tag+ instead of a raw HTML tag
      # @param simple_tag [String] the Markdown delimiter
      # @param tag [String] the HTML tag name (only used by the
      #   single-string path, via `super`)
      # @return [void]
      #
      def handle_tag(nodes, simple_tag, tag)
        if nodes.size == 1 && String === nodes[0]
          super
        else
          emit_inline(simple_tag)
          traverse_inline_nodes(nodes)
          emit_inline(simple_tag)
        end
      end
    end
  end
end
