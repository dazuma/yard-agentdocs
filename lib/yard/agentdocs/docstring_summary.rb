# frozen_string_literal: true

require "yard/agentdocs/provenance_marker"

module YARD
  module AgentDocs
    ##
    # A byte-for-byte port of `YARD::Docstring#summary`'s first-sentence-or-
    # first-paragraph extraction (`yard/docstring.rb`), with two behavior
    # changes:
    #
    # 1. A small set of abbreviations that always introduce follow-up prose
    #    (`"e.g."`, `"i.e."`, `"cf."`, `"vs."`, `"a.k.a."`, `"viz."`) are
    #    never treated as ending a sentence, so `"...enum-like field, e.g.
    #    \`val1\`, \`val2\`."` no longer truncates to a dangling `"...e.g."`
    #    — see "Docstring#summary's abbreviation-blind truncation" under
    #    "Decisions" in docs/dev/DESIGN.md for the full rationale, including
    #    why `"etc."`/`"et al."` are deliberately *not* on the list.
    # 2. A leading sentence of {LOW_INFORMATION_WORD_LIMIT} words or fewer
    #    (e.g. `"Optional."`, `"Output only."`) is merged with the sentence
    #    that follows it, provided one exists in the same paragraph —
    #    unlike case 1, the leading sentence here is a real, correctly
    #    parsed sentence, just not an informative one on its own. See
    #    "Docstring#summary extracting a real, complete, but
    #    zero-information first sentence" under "Decisions" in
    #    docs/dev/DESIGN.md. Only one merge ever happens, even if the
    #    resulting second sentence is itself short.
    # 3. The extracted text's own terminal punctuation is no longer always a
    #    blind appended `"."` — see {#terminal_punctuate}. A trailing `:` (an
    #    intro clause cut off right before a list) gets `" ..."` instead,
    #    reading as "there's more, elided" rather than a dangling
    #    colon-period. See "Docstring#summary/smart_summary blindly appends
    #    a trailing period" under "Decisions" in docs/dev/DESIGN.md.
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
    # Separately from the port: the docstring is first passed through
    # {ProvenanceMarker#strip_provenance}, so an `.rbs`-sourced docstring's
    # leading `rdoc-file=` marker can't become the extracted summary. That
    # is input sanitation, not a fourth deviation from YARD's algorithm —
    # the extraction below sees exactly the text a marker-free docstring
    # would have given it.
    #
    module DocstringSummary
      include ProvenanceMarker

      # Abbreviations whose meaning always sets off prose that follows them
      # (an example, a restatement, a comparison target), so their period
      # should never read as a sentence's end. Deliberately excludes
      # `"etc."`/`"et al."`, which can legitimately close a sentence on
      # their own — see "Docstring#summary's abbreviation-blind truncation"
      # under "Decisions" in docs/dev/DESIGN.md.
      SKIP_ABBREVIATIONS = ["e.g.", "i.e.", "cf.", "vs.", "a.k.a.", "viz."].freeze
      private_constant :SKIP_ABBREVIATIONS

      # The maximum word count (inclusive) a leading sentence can have and
      # still be considered a low-information annotation eligible to be
      # merged with the sentence that follows it — see the module doc's
      # second behavior change. Chosen to cover the measured real-world
      # patterns (`"Optional."` at 1 word, `"Output only."`/`"Input only."`
      # at 2) without needing a fixed vocabulary list.
      LOW_INFORMATION_WORD_LIMIT = 2
      private_constant :LOW_INFORMATION_WORD_LIMIT

      # A leading sentence only counts as a low-information annotation if,
      # besides its final period, it's made up of nothing but
      # {LOW_INFORMATION_WORD_LIMIT} (or fewer) plain, hyphenatable words —
      # deliberately excludes anything containing an inline `{Class#method}`
      # reference, backtick-quoted code, or a second embedded period (e.g.
      # an ellipsis' trailing dots, already treated as one candidate
      # "sentence" by {#raw_end_index}'s decimal/ellipsis handling), all of
      # which are real content, not a short field-behavior annotation, even
      # when word-count alone would call them short. Built from
      # {LOW_INFORMATION_WORD_LIMIT} instead of hardcoding it twice.
      LOW_INFORMATION_PATTERN = /
        \A[[:alpha:]]+(?:-[[:alpha:]]+)*
        (?:\ [[:alpha:]]+(?:-[[:alpha:]]+)*){0,#{LOW_INFORMATION_WORD_LIMIT - 1}}
        \z
      /x
      private_constant :LOW_INFORMATION_PATTERN

      ##
      # @param docstring [String, ::YARD::Docstring, nil]
      # @return [String] the first sentence (or first paragraph, if it has
      #   no sentence-ending period) of +docstring+, always ending in a
      #   period — except when the entire result is an `{include:...}`
      #   directive, left as-is so it still resolves at render time. Empty
      #   if +docstring+ is blank.
      #
      def smart_summary(docstring)
        stripped = strip_provenance(docstring).gsub(/[\r\n](?![\r\n])/, " ").strip
        summary = stripped[0..end_index(stripped)].to_s
        terminal_punctuate(summary)
      end

      private

      # {#smart_summary}'s own terminal-punctuation rule: a trailing `:` (an
      # intro clause cut off right before a list, or a bare `:nodoc:`-shaped
      # directive token, which is bounded by colons front and back either
      # way) gets `" ..."` instead of a blind `"."` — reading as "there's
      # more, elided" rather than a dangling colon-period. Every other
      # extracted text, including one ending in a Markdown styling
      # delimiter (an inline-code backtick, `*emphasis*`) rather than the
      # underlying prose's own last letter, still gets the unconditional
      # `"."` exactly as before; only a literal trailing colon is
      # measured evidence of this bug (see "Docstring#summary/smart_summary
      # blindly appends a trailing period" under "Decisions" in
      # docs/dev/DESIGN.md) — not a reason to second-guess every other
      # non-alphanumeric ending. `{include:...}` is left alone either way,
      # since it isn't real sentence text at all.
      def terminal_punctuate(summary)
        return summary if summary.empty? || summary =~ /\A\s*\{include:.+\}\s*\Z/
        return "#{summary} ..." if summary.end_with?(":")

        "#{summary}."
      end

      # The index +stripped+'s summary should end at: {#raw_end_index}'s
      # result, extended by one more sentence when that first sentence is a
      # low-information leading annotation (see the module doc's second
      # behavior change and {#low_information_extension_start}). Never
      # extends more than once, even if the resulting second sentence is
      # itself short.
      def end_index(stripped)
        first_index = raw_end_index(stripped)
        extension_start = low_information_extension_start(stripped, first_index)
        return first_index if extension_start.nil?

        extension_start + raw_end_index(stripped[extension_start..])
      end

      # Scans +text+ for the index its summary should end at (the
      # character just before a sentence-ending "." or a paragraph break),
      # falling back to the last index of +text+ if neither ever occurs.
      # Ported from `Docstring#summary`'s `length.times` loop, with
      # {#abbreviation_before?} gating the "." branch — the "\r"/"\n"
      # (paragraph break) branch is intentionally untouched, since no
      # fixture or dogfood evidence has ever shown a paragraph ending
      # mid-abbreviation. Also reused, on a substring, by {#end_index} to
      # scan for a low-information leading sentence's follow-up.
      def raw_end_index(text)
        num_parens = 0
        text.length.times do |index|
          case text[index, 1]
          when "."
            next_char = text[index + 1, 1].to_s
            if num_parens <= 0 && next_char =~ /^\s*$/ && !abbreviation_before?(text, index)
              return index - 1
            end
          when "\r", "\n"
            next_char = text[index + 1, 1].to_s
            return text[index - 1, 1] == "." ? index - 2 : index - 1 if next_char =~ /^\s*$/
          when "{", "(", "["
            num_parens += 1
          when "}", ")", "]"
            num_parens -= 1
          end
        end
        text.length - 1
      end

      # Whether the leading sentence ending at +first_index+ (an index into
      # +stripped+, as returned by {#raw_end_index}) is a low-information
      # annotation that should be merged with the sentence following it —
      # see the module doc's second behavior change. Returns the index in
      # +stripped+ the follow-up scan should start from (the whitespace
      # right after the leading sentence's period, kept so {#raw_end_index}
      # sees the same leading-whitespace shape it always does), or +nil+ if
      # no merge should happen: +first_index+ doesn't end on a real
      # sentence period (as opposed to the paragraph-break fallback), the
      # candidate doesn't match {LOW_INFORMATION_PATTERN}, nothing follows
      # it, or what follows is a new paragraph (a "\r"/"\n"
      # survives {#smart_summary}'s newline collapse only at an original
      # blank-line paragraph break — a single line-wrap collapses to a
      # plain space and so never blocks the merge).
      def low_information_extension_start(stripped, first_index)
        return nil unless stripped[first_index + 1, 1] == "."
        return nil unless stripped[0..first_index] =~ LOW_INFORMATION_PATTERN

        rest_start = first_index + 2
        offset = stripped[rest_start..].to_s.index(/[^ \t]/)
        return nil if offset.nil? || stripped[rest_start + offset, 1] =~ /[\r\n]/

        rest_start
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
