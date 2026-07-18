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
      # @return [String, nil] every type the attribute's declared `@return`
      #   tag lists, comma-joined — same union policy as
      #   {MethodSignature#signature_return_type}, extended here since this
      #   helper doesn't funnel through {CrossReferencing#type_ref_first}
      #   (see "Union types on the remaining first-type-only tag sites"
      #   under "Decisions" in devdocs/DESIGN.md)
      #
      def attribute_type(attr)
        attr.source_method.tag(:return)&.types&.join(", ")
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
      # @return [String] Markdown
      #
      def attribute_docstring(attr)
        markdownify(attr.source_method.docstring)
      end

      ##
      # @param attr [Attribute]
      # @return [String]
      #
      def attribute_docstring_summary(attr)
        attr.source_method.docstring.summary
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
