# frozen_string_literal: true

require "helper"

describe ::YARD::AgentDocs::ProvenanceMarker do
  let(:holder) { agentdocs_holder(::YARD::AgentDocs::ProvenanceMarker) }

  # Every marker below is vendored verbatim from a real `.rbs` file
  # installed locally, not invented for the test — the point is to assert
  # against the shapes RBS actually emits. They were drawn from a survey
  # of the locally installed `.rbs` corpus: 467 marker-bearing files,
  # 14,525 marker-bearing comment blocks, two forms, none ever
  # non-leading.
  describe "real markers from installed gems" do
    it "strips the one-line Form A marker (base64-0.3.0/sig/base64.rbs)" do
      docstring = "<!-- rdoc-file=lib/base64.rb -->\nModule Base64 provides methods for:"
      assert_equal("Module Base64 provides methods for:", holder.strip_provenance(docstring))
    end

    it "strips the multi-line Form B marker (prime-0.1.4/sig/prime.rbs)" do
      docstring = <<~DOC
        <!--
          rdoc-file=lib/prime.rb
          - each(ubound = nil, generator = EratosthenesGenerator.new, &block)
        -->
        Iterates the given block over all prime numbers.
      DOC
      assert_equal("Iterates the given block over all prime numbers.\n", holder.strip_provenance(docstring))
    end

    it "strips a Form B marker carrying the observed maximum of 8 call-seq lines (rbs-3.10.0/core/array.rbs)" do
      docstring = <<~DOC
        <!--
          rdoc-file=array.c
          - self[index] -> object or nil
          - self[start, length] -> object or nil
          - self[range] -> object or nil
          - self[aseq] -> object or nil
          - slice(index) -> object or nil
          - slice(start, length) -> object or nil
          - slice(range) -> object or nil
          - slice(aseq) -> object or nil
        -->
        Returns elements from `self`; does not modify `self`.
      DOC
      assert_equal("Returns elements from `self`; does not modify `self`.\n", holder.strip_provenance(docstring))
    end
  end

  describe "text it must leave alone" do
    # The whole reason the pattern is anchored and `rdoc-file=`-bearing
    # rather than a general HTML-comment strip: each of these is real
    # documentation content from a real bundle.
    it "leaves an HTML comment discussed mid-prose alone (REXML::Comment)" do
      docstring = "Represents an XML comment; that is, text between <!-- ... -->"
      assert_equal(docstring, holder.strip_provenance(docstring))
    end

    it "leaves a grammar rule naming HTML comments alone (RDoc::Markdown)" do
      docstring = %(HtmlComment = "<!--" (!"-->" .)* "-->")
      assert_equal(docstring, holder.strip_provenance(docstring))
    end

    it "leaves a leading HTML comment that is not a provenance marker alone" do
      docstring = "<!-- run-end -->\nSome prose."
      assert_equal(docstring, holder.strip_provenance(docstring))
    end

    it "leaves a marker that does not lead the docstring alone" do
      docstring = "Some prose.\n<!-- rdoc-file=lib/base64.rb -->"
      assert_equal(docstring, holder.strip_provenance(docstring))
    end

    it "leaves a Form B-shaped block with no rdoc-file line alone" do
      docstring = "<!--\n  - each(ubound = nil)\n-->\nProse."
      assert_equal(docstring, holder.strip_provenance(docstring))
    end
  end

  describe "edge cases" do
    it "returns an empty string for nil" do
      assert_equal("", holder.strip_provenance(nil))
    end

    it "accepts a YARD::Docstring, not just a String" do
      docstring = ::YARD::Docstring.new("<!-- rdoc-file=lib/base64.rb -->\nProse.")
      assert_equal("Prose.", holder.strip_provenance(docstring))
    end

    it "consumes only the marker's own newline, leaving the docstring's blank lines" do
      docstring = "<!-- rdoc-file=lib/base64.rb -->\n\nProse after a blank line."
      assert_equal("\nProse after a blank line.", holder.strip_provenance(docstring))
    end

    it "returns an empty string when the marker is the entire docstring" do
      assert_equal("", holder.strip_provenance("<!-- rdoc-file=lib/base64.rb -->"))
    end
  end
end
