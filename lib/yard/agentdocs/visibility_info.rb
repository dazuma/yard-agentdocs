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
      # @param obj [::YARD::CodeObjects::Base]
      # @return [Boolean] whether the object is tagged `@private` or
      #   `@api private`
      #
      def private_api?(obj)
        obj.has_tag?(:private) || (obj.has_tag?(:api) && obj.tag(:api).text == "private")
      end

      ##
      # Bold-line annotation, e.g. for a `**Private API.**` metadata line.
      #
      # @param obj [::YARD::CodeObjects::Base]
      # @return [String, nil]
      #
      def private_api_annotation(obj)
        "Private API." if private_api?(obj)
      end

      ##
      # Parenthetical annotation for a Member Summary bullet, e.g.
      # `(private API)`.
      #
      # @param obj [::YARD::CodeObjects::Base]
      # @return [String, nil]
      #
      def private_api_annotation_short(obj)
        "private API" if private_api?(obj)
      end
    end
  end
end
