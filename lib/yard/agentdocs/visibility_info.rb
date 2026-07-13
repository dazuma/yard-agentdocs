# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # Tag-based-privacy helpers shared by the `module`/`class` `agentdocs`
    # templates: a Ruby-public method can still be flagged as not part of the
    # stable API via the `@private` tag or an `@api private` tag. Unlike
    # Ruby-scope `private`/`protected` (excluded from the registry query
    # before any template ever sees them), these methods are still rendered
    # — just annotated — matching YARD's own default HTML template behavior.
    #
    module VisibilityInfo
      ##
      # @param object [::YARD::CodeObjects::Base]
      # @return [Boolean] whether the object is tagged `@private` or
      #   `@api private`
      #
      def private_api?(object)
        object.has_tag?(:private) || (object.has_tag?(:api) && object.tag(:api).text == "private")
      end

      ##
      # Bold-line annotation, e.g. for a `**Private API.**` metadata line.
      #
      # @param object [::YARD::CodeObjects::Base]
      # @return [String, nil]
      #
      def private_api_annotation(object)
        "Private API." if private_api?(object)
      end

      ##
      # Parenthetical annotation for a Member Summary bullet, e.g.
      # `(private API)`.
      #
      # @param object [::YARD::CodeObjects::Base]
      # @return [String, nil]
      #
      def private_api_annotation_short(object)
        "private API" if private_api?(object)
      end
    end
  end
end
