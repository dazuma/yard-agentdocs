# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # Markdown-list-item text-layout helpers shared by the `module`/`class`
    # `agentdocs` templates: joining a tag's type/prefix onto its
    # description text, and keeping a multi-line description safely nested
    # inside its enclosing `- ` bullet.
    #
    # Requires the including template to also have {Markdownify} mixed in
    # (for `markdownify`), as `module/agentdocs/setup.rb` does.
    #
    module TextLayout
      ##
      # No " — text" suffix at all when +text+ is blank (e.g. no doc comment,
      # or a tag with no trailing description) — same "absence means empty"
      # convention as an empty Member Summary subgroup, rather than a
      # dangling trailing dash. For a fixed, unconditionally-rendered prefix
      # (Member Summary bullets; a Params/Yield Params bullet's
      # already-parenthesized type).
      #
      # @param text [String, ::YARD::Docstring, nil]
      # @return [String]
      #
      def summary_suffix(text)
        markdown = markdownify(text)
        markdown.empty? ? "" : " — #{indent_continuation(markdown)}"
      end

      ##
      # Like {#summary_suffix}, but for a prefix that can itself be
      # legitimately blank (a tag with no bracketed type, or no yielded
      # names) — joins whichever of +prefix+/+text+ are non-blank with
      # " — ", instead of always rendering +prefix+ first. Used for
      # Returns/Yield Returns/Raises/Yields, where the type isn't wrapped in
      # its own always-present punctuation the way a Params bullet's parens
      # are.
      #
      # @param prefix [String, nil]
      # @param text [String, ::YARD::Docstring, nil]
      # @return [String]
      #
      def dash_join(prefix, text)
        markdown = markdownify(text)
        [prefix, indent_continuation(markdown)].reject { |s| s.to_s.empty? }.join(" — ")
      end

      ##
      # Every caller of {#summary_suffix}/{#dash_join} splices its result
      # onto a single `- ` list-item bullet (Member Summary, Params/Yield
      # Params/Raises, Options, and — per the Returns/Yields/Yield Returns
      # bullet-list shape — those too).
      # A tag's raw +text+ can itself be multi-line (a soft-wrapped
      # description, or genuine multi-paragraph prose with a nested list —
      # real-world docstrings do this, e.g. API-client gems generated from
      # language-agnostic specs), and splicing that verbatim would place
      # later lines at column 0 in the output file — silently breaking out
      # of the list item (or worse: an unmatched ` ``` ` landing at a line
      # start opens an unclosed fence that swallows the rest of the document
      # as code, verified against a real CommonMark parser). Indenting every
      # line after the first by the width of a `- ` marker keeps the
      # content nested as that one list item's continuation (verified this
      # doesn't need to match the bullet's own, longer, visible prefix —
      # just the marker) — and, as a side effect, keeps a prose-embedded
      # `#`/`##` line from ever matching this format's own `grep '^## '`-style
      # heading lookup, since it's indented, not at true column 0.
      #
      # @param markdown [String]
      # @param width [Integer]
      # @return [String]
      #
      def indent_continuation(markdown, width: 2)
        lines = markdown.split("\n", -1)
        return markdown if lines.size <= 1
        indent = " " * width
        ([lines.first] + lines[1..].map { |line| line.empty? ? line : "#{indent}#{line}" }).join("\n")
      end
    end
  end
end
