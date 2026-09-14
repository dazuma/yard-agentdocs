# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # Removes the RBS provenance marker that leads a docstring imported
    # from RDoc into an `.rbs` signature file.
    #
    # RBS emits an `rdoc-file=` HTML comment at the head of every doc
    # comment it imports, recording which Ruby source the prose came from.
    # The marker is invisible in HTML, which is why it survives upstream
    # unnoticed, but this format is read as plain text: left in place it
    # renders as body content, becomes the leading text of the extracted
    # summary, and from there reaches the `description:` frontmatter, the
    # `index.md` entry, and the parent's `## Member Summary` entry. It
    # carries nothing the rendered page doesn't already state — the
    # `**Defined in:**` line names the same files. See "RBS provenance
    # markers in `.rbs`-sourced docstrings" under "Decisions" in
    # docs/dev/DESIGN.md, and issue #1.
    #
    # Deliberately *not* a general HTML-comment strip: an HTML comment is
    # legitimate documentation content elsewhere (`REXML::Comment`
    # documents XML comments, `RDoc::Markdown` documents an
    # `HtmlComment` grammar rule), so only this one anchored, `rdoc-file=`
    # bearing shape is recognized.
    #
    module ProvenanceMarker
      # The one-line form, `<!-- rdoc-file=lib/base64.rb -->`. Anchored at
      # the start of the docstring: across every `.rbs` file installed
      # locally (14,525 marker-bearing comment blocks) not one marker
      # appeared anywhere but the first line of its block, so anchoring
      # costs no coverage and makes a false positive against prose that
      # merely *discusses* such a comment structurally impossible.
      FORM_A = /\A<!--[ \t]*rdoc-file=\S*[ \t]*-->[ \t]*\r?\n?/
      private_constant :FORM_A

      # The multi-line form — roughly twice as common as {FORM_A} — whose
      # body is an `rdoc-file=` line plus up to eight RDoc call-seq lines:
      #
      #     <!--
      #       rdoc-file=lib/prime.rb
      #       - each(ubound = nil, generator = EratosthenesGenerator.new, &block)
      #     -->
      #
      # Every inner line must be one of those two shapes, and at least one
      # must be the `rdoc-file=` line (checked by {#strip_provenance}, not
      # expressible here without duplicating the alternation) — a leading
      # block of bare signature lines is something else, and no evidence of
      # one exists.
      FORM_B = /\A<!--[ \t]*\r?\n(?:[ \t]*(?:rdoc-file=\S*|-[ \t][^\r\n]*)[ \t]*\r?\n)+[ \t]*-->[ \t]*\r?\n?/
      private_constant :FORM_B

      ##
      # @param text [String, ::YARD::Docstring, nil]
      # @return [String] +text+ with a leading RBS provenance marker
      #   removed, consuming the marker and the single newline that ends
      #   it and nothing more — the docstring's own blank lines survive, so
      #   downstream whitespace handling behaves exactly as it does on a
      #   docstring that never had a marker. Returns +text+ unchanged when
      #   it doesn't start with one, which is the overwhelmingly common
      #   case.
      #
      def strip_provenance(text)
        string = text.to_s
        return string.sub(FORM_A, "") if FORM_A.match?(string)

        match = FORM_B.match(string)
        return string unless match && match[0].include?("rdoc-file=")

        match.post_match
      end
    end
  end
end
