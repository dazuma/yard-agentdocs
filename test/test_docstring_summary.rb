# frozen_string_literal: true

require "helper"

describe ::YARD::AgentDocs::DocstringSummary do
  let(:holder) { agentdocs_holder(::YARD::AgentDocs::DocstringSummary) }

  # Every case here is ported directly from YARD's own `#summary` spec
  # (`docstring_spec.rb`, `describe "#summary"` block) — not reinterpreted
  # from reading `docstring.rb`. Each asserts the literal expected value
  # *and* that the real `Docstring#summary` still agrees with it, so this
  # suite doubles as a live proof that {DocstringSummary#smart_summary} is
  # no worse than the currently-installed `yard` gem for every case it
  # already handled, not just the new abbreviation-skip-list behavior.
  describe "parity with YARD::Docstring#summary" do
    it "handles an empty docstring" do
      doc = ::YARD::Docstring.new
      assert_equal("", doc.summary)
      assert_equal("", holder.smart_summary(doc))
    end

    it "strips newlines in the first paragraph before summarizing" do
      doc = ::YARD::Docstring.new("Foo\n<code>==</code> bar.")
      assert_equal("Foo <code>==</code> bar.", doc.summary)
      assert_equal("Foo <code>==</code> bar.", holder.smart_summary(doc))
    end

    it "returns just the first sentence" do
      # YARD's own spec uses "DOCSTRING. Another sentence" here, but that
      # placeholder's first sentence happens to be a single plain word —
      # exactly the shape the new low-information-leading-sentence merge
      # (see "low-information leading sentence merge" below) targets, which
      # would make this coincidentally exercise that behavior instead of
      # the plain first-sentence extraction this test is actually for. Use
      # a first sentence with more than {LOW_INFORMATION_WORD_LIMIT} words
      # instead so the two stay independent.
      doc = ::YARD::Docstring.new("A short docstring. Another sentence")
      assert_equal("A short docstring.", doc.summary)
      assert_equal("A short docstring.", holder.smart_summary(doc))
    end

    it "returns the first paragraph when it has no sentence-ending period" do
      doc = ::YARD::Docstring.new("DOCSTRING, and other stuff\n\nAnother sentence.")
      assert_equal("DOCSTRING, and other stuff.", doc.summary)
      assert_equal("DOCSTRING, and other stuff.", holder.smart_summary(doc))
    end

    it "does not double the ending period" do
      doc = ::YARD::Docstring.new(
        "Returns a list of tags specified by +name+ or all tags if +name+ is not specified.\n\nTest"
      )
      expected = "Returns a list of tags specified by +name+ or all tags if +name+ is not specified."
      assert_equal(expected, doc.summary)
      assert_equal(expected, holder.smart_summary(doc))
    end

    it "does not double the ending period when tags follow in the same docstring" do
      doc = ::YARD::Docstring.new(<<~TEXT)
        Returns a list of tags specified by +name+ or all tags if +name+ is not specified.

        @param name the tag name to return data for, or nil for all tags
        @return [Array<Tags::Tag>] the list of tags by the specified tag name
      TEXT
      expected = "Returns a list of tags specified by +name+ or all tags if +name+ is not specified."
      assert_equal(expected, doc.summary)
      assert_equal(expected, holder.smart_summary(doc))
    end

    it "does not attach a period if the entire summary is an {include:...} directive" do
      ::YARD.parse_string "# docstring\ndef foo; end"
      doc = ::YARD::Docstring.new("{include:#foo}")
      assert_equal("{include:#foo}", doc.summary)
      assert_equal("{include:#foo}", holder.smart_summary(doc))
      ::YARD::Registry.clear
    end

    it "handles inline {Class#method} references embedded in the summary" do
      doc = ::YARD::Docstring.new("Aliasing {Test.test}. Done.")
      assert_equal("Aliasing {Test.test}.", doc.summary)
      assert_equal("Aliasing {Test.test}.", holder.smart_summary(doc))
    end

    it "only ends the first sentence on a period outside parentheses" do
      doc = ::YARD::Docstring.new("Hello (the best.) world. Foo bar.")
      assert_equal("Hello (the best.) world.", doc.summary)
      assert_equal("Hello (the best.) world.", holder.smart_summary(doc))
    end

    it "only ends the first sentence on a period outside brackets" do
      doc = ::YARD::Docstring.new("A[b.]c.")
      assert_equal("A[b.]c.", doc.summary)
      assert_equal("A[b.]c.", holder.smart_summary(doc))
    end

    it "only treats '.' as a period when whitespace or end-of-string follows (decimal numbers)" do
      doc = ::YARD::Docstring.new("hello 1.5 times.")
      assert_equal("hello 1.5 times.", doc.summary)
      assert_equal("hello 1.5 times.", holder.smart_summary(doc))
    end

    it "only treats '.' as a period when whitespace or end-of-string follows (ellipses)" do
      doc = ::YARD::Docstring.new("hello... me")
      assert_equal("hello...", doc.summary)
      assert_equal("hello...", holder.smart_summary(doc))
    end

    it "only treats '.' as a period when whitespace or end-of-string follows (bare trailing period)" do
      doc = ::YARD::Docstring.new("hello.")
      assert_equal("hello.", doc.summary)
      assert_equal("hello.", holder.smart_summary(doc))
    end

    it "falls back to the paragraph break when parenthesis counting is thrown off (unmatched close)" do
      doc = ::YARD::Docstring.new("Happy method call :-)\n\nCall any time.")
      assert_equal("Happy method call :-).", doc.summary)
      assert_equal("Happy method call :-).", holder.smart_summary(doc))
    end

    it "falls back to the paragraph break when parenthesis counting is thrown off (unmatched open)" do
      doc = ::YARD::Docstring.new("Sad method call :-(\n\nCall any time.")
      assert_equal("Sad method call :-(.", doc.summary)
      assert_equal("Sad method call :-(.", holder.smart_summary(doc))
    end

    it "does not double the period at a paragraph break that already ends in one" do
      doc = ::YARD::Docstring.new("Hello (World. Forget to close.\n\nNew text")
      assert_equal("Hello (World. Forget to close.", doc.summary)
      assert_equal("Hello (World. Forget to close.", holder.smart_summary(doc))
    end

    it "adds a period at a paragraph break that doesn't already end in one" do
      doc = ::YARD::Docstring.new("Hello (World. Forget to close\n\nNew text")
      assert_equal("Hello (World. Forget to close.", doc.summary)
      assert_equal("Hello (World. Forget to close.", holder.smart_summary(doc))
    end
  end

  # New behavior: {DocstringSummary::SKIP_ABBREVIATIONS} (private, but
  # exercised end to end here) — abbreviations that always introduce
  # follow-up prose are never mistaken for a sentence's end. This is where
  # {#smart_summary} deliberately diverges from `Docstring#summary`, so
  # these assert the corrected literal text rather than parity with it.
  describe "abbreviation skip-list" do
    it "does not end the sentence at 'e.g.'" do
      text = "An enum-like field, e.g. `val1`, `val2`. More prose."
      assert_equal("An enum-like field, e.g. `val1`, `val2`.", holder.smart_summary(text))
    end

    it "does not end the sentence at 'i.e.'" do
      text = "The rounding mode, i.e. `:up` or `:down`. Defaults to `:up`."
      assert_equal("The rounding mode, i.e. `:up` or `:down`.", holder.smart_summary(text))
    end

    it "does not end the sentence at 'cf.'" do
      text = "Uses the same scale, cf. the `#priority` attribute. See below."
      assert_equal("Uses the same scale, cf. the `#priority` attribute.", holder.smart_summary(text))
    end

    it "does not end the sentence at 'vs.'" do
      text = "A comparison of seconds vs. milliseconds. Explained further."
      assert_equal("A comparison of seconds vs. milliseconds.", holder.smart_summary(text))
    end

    it "does not end the sentence at 'a.k.a.'" do
      text = "Known as the epoch, a.k.a. `Time.at(0)`. More detail."
      assert_equal("Known as the epoch, a.k.a. `Time.at(0)`.", holder.smart_summary(text))
    end

    it "does not end the sentence at 'viz.'" do
      text = "Two states, viz. `:open` and `:closed`. Nothing else."
      assert_equal("Two states, viz. `:open` and `:closed`.", holder.smart_summary(text))
    end

    it "matches case-insensitively" do
      text = "Some values, E.G. `1`, `2`. More prose."
      assert_equal("Some values, E.G. `1`, `2`.", holder.smart_summary(text))
    end

    it "skips the abbreviation even at the very start of the text" do
      text = "E.g. this still works. More prose."
      assert_equal("E.g. this still works.", holder.smart_summary(text))
    end

    it "does not fire on a word that merely ends the same way, across a non-word boundary" do
      # "e" is directly preceded by a digit ("1e.g." has no word boundary before "e"),
      # so this must NOT be treated as the "e.g." abbreviation.
      text = "A code like 1e.g. is not an abbreviation. More prose."
      assert_equal("A code like 1e.g.", holder.smart_summary(text))
    end

    it "still ends the sentence at 'etc.' (not on the skip-list, can legitimately end a sentence)" do
      text = "Plain, bold, colored, etc. Additional styles may be added later."
      assert_equal("Plain, bold, colored, etc.", holder.smart_summary(text))
    end

    it "still ends the sentence at 'et al.' (not on the skip-list, can legitimately end a sentence)" do
      text = "Originally proposed by Smith et al. It has since been revised."
      assert_equal("Originally proposed by Smith et al.", holder.smart_summary(text))
    end
  end

  # New behavior: a short, real, correctly-parsed leading sentence (see
  # {LOW_INFORMATION_WORD_LIMIT}, private but exercised end to end here) is
  # merged with the sentence that follows it, rather than left standing
  # alone as a zero-information summary. Unlike the abbreviation skip-list
  # above, no misparse is involved — the period genuinely ends a sentence —
  # so these assert the corrected literal text rather than parity with
  # `Docstring#summary`.
  describe "low-information leading sentence merge" do
    it "merges a one-word leading sentence with the sentence that follows it" do
      text = "Optional. Custom metadata about the secret. Annotations are distinct from labels."
      assert_equal("Optional. Custom metadata about the secret.", holder.smart_summary(text))
    end

    it "merges a two-word leading sentence with the sentence that follows it" do
      text = "Output only. The value is populated by the server. Ignored on input."
      assert_equal("Output only. The value is populated by the server.", holder.smart_summary(text))
    end

    it "does not merge a three-word leading sentence (above the word limit)" do
      text = "Not always set. More detail follows in this paragraph."
      assert_equal("Not always set.", holder.smart_summary(text))
    end

    it "leaves a low-information leading sentence alone when nothing follows it" do
      text = "Optional."
      assert_equal("Optional.", holder.smart_summary(text))
    end

    it "does not merge across a paragraph break (blank line)" do
      text = "Optional.\n\nCustom metadata about the secret."
      assert_equal("Optional.", holder.smart_summary(text))
    end

    it "still merges across a single line-wrap newline (not a paragraph break)" do
      text = "Optional.\nCustom metadata about the secret."
      assert_equal("Optional. Custom metadata about the secret.", holder.smart_summary(text))
    end

    it "only merges once, even when the newly-merged-in sentence is itself short" do
      text = "Optional. Brief. Custom metadata about the secret, described at length here."
      assert_equal("Optional. Brief.", holder.smart_summary(text))
    end

    it "does not merge when the leading sentence's period is skipped as an abbreviation" do
      # "e.g." is only 1 "word" by whitespace-splitting, but abbreviation_before?
      # already prevents its period from ending a sentence at all, so this
      # never reaches the merge decision in the first place.
      text = "An enum-like field, e.g. `val1`, `val2`. More prose."
      assert_equal("An enum-like field, e.g. `val1`, `val2`.", holder.smart_summary(text))
    end
  end

  describe "blank input" do
    it "returns an empty string for nil" do
      assert_equal("", holder.smart_summary(nil))
    end

    it "returns an empty string for an empty string" do
      assert_equal("", holder.smart_summary(""))
    end
  end
end
