# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # Attribute-data helpers shared by the `module`/`class` `agentdocs`
    # templates, operating on the {Attribute} value
    # {MemberListing#class_attribute_objects}/{MemberListing#instance_attribute_objects}
    # build for each `attr_reader`/`attr_writer`/`attr_accessor` declaration.
    #
    module AttributeInfo
      ##
      # @param attr [Attribute]
      # @return [String] e.g. `.verbose` or `#width` — `.` for a class-level
      #   attribute ({Attribute#class_level?}), `#` for an instance-level one
      #
      def attribute_heading(attr)
        "#{attr.class_level? ? '.' : '#'}#{attr.name}"
      end

      ##
      # @param attr [Attribute]
      # @return [String] every type the attribute's declared `@return` tag
      #   lists, comma-joined — same union policy as
      #   {MethodSignature#signature_return_type}, extended here since this
      #   helper doesn't funnel through {CrossReferencing#type_ref_first}
      #   (see "Union types on the remaining first-type-only tag sites"
      #   under "Decisions" in devdocs/DESIGN.md). Falls back to `"Object"`
      #   when there's no `@return` tag (or one with no declared types) —
      #   a plain, comment-less `attr_reader`/`writer`/`accessor` never gets
      #   one, unlike `Struct.new`/`Data.define`'s synthesized accessors —
      #   matching YARD's own human-facing template default for the same
      #   case (see "Attribute `**Type:**` fallback for a plain… `attr_*`"
      #   under "Decisions" in devdocs/DESIGN.md)
      #
      def attribute_type(attr)
        types = attr.source_method.tag(:return)&.types
        types.nil? || types.empty? ? "Object" : types.join(", ")
      end

      ##
      # Bold-line annotation, e.g. for a `**Read-only.**` metadata line.
      #
      # @param attr [Attribute]
      # @return [String, nil]
      #
      def attribute_annotation(attr)
        return "Read-only." if attr.write.nil?
        return "Write-only." if attr.read.nil?
        nil
      end

      ##
      # Parenthetical annotation for a Member Summary bullet, e.g.
      # `(read-only)`.
      #
      # @param attr [Attribute]
      # @return [String, nil]
      #
      def attribute_annotation_short(attr)
        return "read-only" if attr.write.nil?
        return "write-only" if attr.read.nil?
        nil
      end

      ##
      # @param attr [Attribute]
      # @return [String] Markdown. Falls back to the source method's
      #   `@return` tag text, verbatim (no re-casing or "Returns" wrapping —
      #   matches how every other tag's raw text is rendered elsewhere in
      #   this template, e.g. {TextLayout#dash_join}), when there's no
      #   separate free-text docstring — a `@!attribute` directive whose
      #   entire description lives inside `@return [Type] Description` has
      #   an empty `docstring` despite having real descriptive text; see
      #   "Attribute description entirely inside a `@!attribute`'s
      #   `@return`" under "Decisions" in devdocs/DESIGN.md
      #
      def attribute_docstring(attr)
        docstring = attr.source_method.docstring
        return markdownify(docstring) unless docstring.empty?

        markdownify(attr.source_method.tag(:return)&.text)
      end

      ##
      # @param attr [Attribute]
      # @return [String] Same `@return`-tag-text fallback as
      #   {#attribute_docstring}, truncated to its first sentence the same
      #   way every other Member Summary bullet's source text is (via
      #   {DocstringSummary#smart_summary})
      #
      def attribute_docstring_summary(attr)
        docstring = attr.source_method.docstring
        return smart_summary(docstring) unless docstring.empty?

        smart_summary(attr.source_method.tag(:return)&.text)
      end

      ##
      # @param attr [Attribute]
      # @return [String] source file path
      #
      def attribute_file(attr)
        attr.source_method.file
      end

      ##
      # @param attr [Attribute]
      # @return [Integer] source line number
      #
      def attribute_line(attr)
        attr.source_method.line
      end
    end
  end
end
