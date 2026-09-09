# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # Whether an object's docstring is a bare RDoc `:nodoc:` directive and
    # nothing else. Shared by {MemberListing} (filtering nested classes/
    # modules, constants, attributes, and methods out of their namespace's
    # own listings) and the `fulldoc/agentdocs` template (filtering the
    # top-level object list, and so `index.md` and which objects get their
    # own page).
    #
    # RDoc's own convention for declaring that an entity — still genuinely
    # Ruby-public and callable — shouldn't be advertised as existing in
    # generated documentation at all. Unlike `@private`/`@api private`
    # ({VisibilityInfo}), which flag a method as shown-but-not-stable, this
    # is a stronger signal, so it's handled the same way as Ruby-scope
    # `private`/`protected` — omitted entirely — rather than shown-and-
    # flagged. See "A docstring whose entire (stripped) content is a bare
    # RDoc `:nodoc:` ... directive token" under "Decisions" in
    # docs/dev/DESIGN.md.
    #
    # Deliberately narrower than RDoc's full directive set: `:stopdoc:`/
    # `:startdoc:`'s real meaning is a block-scoping toggle across otherwise
    # unrelated statements, which can't be recovered at this per-object,
    # template-only layer (the same "no custom handler classes" boundary
    # already excludes it) — approximating that as a per-object filter would
    # misrepresent what those two directives actually do, so a bare
    # `:stopdoc:`/`:startdoc:` docstring is left rendering as literal prose,
    # unimproved.
    #
    module NodocFilter
      ##
      # @param obj [::YARD::CodeObjects::Base]
      # @return [Boolean] whether +obj+'s docstring, stripped, is exactly
      #   `":nodoc:"`
      #
      def bare_nodoc?(obj)
        obj.docstring.to_s.strip == ":nodoc:"
      end
    end
  end
end
