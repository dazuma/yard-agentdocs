# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # A byte-for-byte port of `YARD::Docstring#summary`'s first-sentence-or-
    # first-paragraph extraction (`yard/docstring.rb`), with one behavior
    # change: a small set of abbreviations that always introduce follow-up
    # prose (`"e.g."`, `"i.e."`, `"cf."`, `"vs."`, `"a.k.a."`, `"viz."`) are
    # never treated as ending a sentence, so `"...enum-like field, e.g.
    # \`val1\`, \`val2\`."` no longer truncates to a dangling `"...e.g."` —
    # see "Docstring#summary's abbreviation-blind truncation" under
    # "Decisions" in devdocs/DESIGN.md for the full rationale, including why
    # `"etc."`/`"et al."` are deliberately *not* on the list.
    #
    # Every other behavior — paragraph breaks, paren/bracket-nesting
    # (tracked as one combined depth, not real matching, the same
    # simplification YARD's own scan makes), decimal numbers, ellipses, and
    # the `{include:...}`-directive no-trailing-period rule — is a
    # deliberate port, not a reinterpretation: `test/test_docstring_summary.rb`
    # runs YARD's own `#summary` spec scenarios (`docstring_spec.rb`)
    # through both {#smart_summary} and the real `Docstring#summary`,
    # asserting they agree.
    #
    module DocstringSummary
      # Abbreviations whose meaning always sets off prose that follows them
      # (an example, a restatement, a comparison target), so their period
      # should never read as a sentence's end. Deliberately excludes
      # `"etc."`/`"et al."`, which can legitimately close a sentence on
      # their own — see "Docstring#summary's abbreviation-blind truncation"
      # under "Decisions" in devdocs/DESIGN.md.
      SKIP_ABBREVIATIONS = ["e.g.", "i.e.", "cf.", "vs.", "a.k.a.", "viz."].freeze
      private_constant :SKIP_ABBREVIATIONS

      ##
      # @param docstring [String, ::YARD::Docstring, nil]
      # @return [String] the first sentence (or first paragraph, if it has
      #   no sentence-ending period) of +docstring+, always ending in a
      #   period — except when the entire result is an `{include:...}`
      #   directive, left as-is so it still resolves at render time. Empty
      #   if +docstring+ is blank.
      #
      def smart_summary(docstring)
        stripped = docstring.to_s.gsub(/[\r\n](?![\r\n])/, " ").strip
        summary = stripped[0..end_index(stripped)].to_s
        summary += "." if !summary.empty? && summary !~ /\A\s*\{include:.+\}\s*\Z/
        summary
      end

      private

      # Scans +stripped+ for the index its summary should end at (the
      # character just before a sentence-ending "." or a paragraph break),
      # falling back to the last index of +stripped+ if neither ever
      # occurs. Ported from `Docstring#summary`'s `length.times` loop,
      # with {#abbreviation_before?} gating the "." branch — the "\r"/"\n"
      # (paragraph break) branch is intentionally untouched, since no
      # fixture or dogfood evidence has ever shown a paragraph ending
      # mid-abbreviation.
      def end_index(stripped)
        num_parens = 0
        stripped.length.times do |index|
          case stripped[index, 1]
          when "."
            next_char = stripped[index + 1, 1].to_s
            if num_parens <= 0 && next_char =~ /^\s*$/ && !abbreviation_before?(stripped, index)
              return index - 1
            end
          when "\r", "\n"
            next_char = stripped[index + 1, 1].to_s
            return stripped[index - 1, 1] == "." ? index - 2 : index - 1 if next_char =~ /^\s*$/
          when "{", "(", "["
            num_parens += 1
          when "}", ")", "]"
            num_parens -= 1
          end
        end
        stripped.length - 1
      end

      # Whether the "." at +text[period_index]+ is the final character of
      # one of {SKIP_ABBREVIATIONS}, matched case-insensitively and only at
      # a word boundary (so e.g. some unrelated word ending in the same
      # letters can't false-positive).
      def abbreviation_before?(text, period_index)
        SKIP_ABBREVIATIONS.any? do |abbreviation|
          start = period_index - abbreviation.length + 1
          next false if start.negative?
          next false unless text[start, abbreviation.length].casecmp?(abbreviation)

          boundary = start - 1
          boundary.negative? || text[boundary] !~ /[[:alnum:]]/
        end
      end
    end
  end
end
