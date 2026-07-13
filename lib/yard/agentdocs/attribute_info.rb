# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # Attribute-data helpers shared by the `module`/`class` `agentdocs`
    # templates. `module/agentdocs/setup.rb`'s `attribute_objects` gathers
    # each attribute as a plain `{ name:, read:, write: }` hash (`read`/
    # `write` are the backing `YARD::CodeObjects::MethodObject`s, either of
    # which may be `nil`) rather than a single YARD object, since a
    # reader/writer pair doesn't otherwise have one; these helpers all
    # operate on that hash shape.
    #
    module AttributeInfo
      ##
      # @param attr [Hash] `{ name:, read:, write: }`
      # @return [::YARD::CodeObjects::MethodObject] whichever of the
      #   reader/writer actually exists, preferring the reader
      #
      def attribute_source_method(attr)
        attr[:read] || attr[:write]
      end

      ##
      # @param attr [Hash] `{ name:, read:, write: }`
      # @return [String, nil] the attribute's declared `@return` type
      #
      def attribute_type(attr)
        tag = attribute_source_method(attr).tag(:return)
        tag&.types&.first
      end

      ##
      # Bold-line annotation, e.g. for a `**Read-only.**` metadata line.
      #
      # @param attr [Hash] `{ name:, read:, write: }`
      # @return [String, nil]
      #
      def attribute_annotation(attr)
        return "Read-only." if attr[:write].nil?
        return "Write-only." if attr[:read].nil?
        nil
      end

      ##
      # Parenthetical annotation for a Member Summary bullet, e.g.
      # `(read-only)`.
      #
      # @param attr [Hash] `{ name:, read:, write: }`
      # @return [String, nil]
      #
      def attribute_annotation_short(attr)
        return "read-only" if attr[:write].nil?
        return "write-only" if attr[:read].nil?
        nil
      end

      ##
      # @param attr [Hash] `{ name:, read:, write: }`
      # @return [String] Markdown
      #
      def attribute_docstring(attr)
        markdownify(attribute_source_method(attr).docstring)
      end

      ##
      # @param attr [Hash] `{ name:, read:, write: }`
      # @return [String]
      #
      def attribute_docstring_summary(attr)
        attribute_source_method(attr).docstring.summary
      end

      ##
      # @param attr [Hash] `{ name:, read:, write: }`
      # @return [String] source file path
      #
      def attribute_file(attr)
        attribute_source_method(attr).file
      end

      ##
      # @param attr [Hash] `{ name:, read:, write: }`
      # @return [Integer] source line number
      #
      def attribute_line(attr)
        attribute_source_method(attr).line
      end
    end
  end
end
