# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # Names-only inherited/mixed-in member roster for the `## Member
    # Summary` section, shared by the `module`/`class` `agentdocs`
    # templates: one bullet per directly-known ancestor/mixin (immediate
    # superclass, each directly `include`d module, each directly `extend`ed
    # module — the same "one reliable hop" set {CrossReferencing}'s
    # `superclass_line`/`includes_line`/`extends_line` already link to),
    # listing just the member *names* it contributes that this object
    # doesn't already list itself. See docs/dev/DESIGN.md's "Names-only
    # inherited/mixin member roster" decision.
    #
    # Requires the including template to provide `object`, plus
    # {MemberListing} (for `constant_objects`/`class_attribute_objects`/
    # `instance_attribute_objects`/`class_method_objects`/
    # `instance_method_objects`, each accepting an optional namespace
    # argument) and
    # {CrossReferencing#link_path}/{CrossReferencing#self_reference?}.
    #
    module MemberRoster
      ##
      # @return [Array<String>] one `"- **Inherited from ...:** ..."`-shaped
      #   bullet per contributing ancestor/mixin, or `[]` if none of them
      #   contribute any name this object doesn't already list itself
      #
      def member_roster_lines
        own = own_member_headings
        [superclass_roster_line(own)].compact + include_roster_lines(own) + extend_roster_lines(own)
      end

      private

      # This object's own member names, in the same display form
      # ({MethodSignature#member_heading}'s sigil convention) its own Member
      # Summary bullets use — the set an ancestor/mixin-contributed name is
      # checked against so an already-visible-on-this-page name (whether a
      # plain shadow or a flagged `**Overrides:**`) never doubles up in the
      # roster.
      def own_member_headings
        constant_objects.map { |c| c.name.to_s } +
          class_attribute_objects.map { |a| ".#{a.name}" } +
          instance_attribute_objects.map { |a| "##{a.name}" } +
          class_method_objects.map { |m| member_heading(m) } +
          instance_method_objects.map { |m| member_heading(m) }
      end

      # A resolved (non-`Proxy`) superclass inherits everything — constants,
      # attributes, class methods, instance methods — unchanged, so its own
      # members keep their natural sigil.
      def superclass_roster_line(own)
        ancestor = object.respond_to?(:superclass) ? object.superclass : nil
        return nil unless ancestor.is_a?(::YARD::CodeObjects::ClassObject)
        headings = (superclass_headings(ancestor) - own).sort
        return nil if headings.empty?
        roster_line("Inherited from", ancestor, headings)
      end

      def superclass_headings(namespace)
        constant_objects(namespace).map { |c| c.name.to_s } +
          class_attribute_objects(namespace).map { |a| ".#{a.name}" } +
          instance_attribute_objects(namespace).map { |a| "##{a.name}" } +
          class_method_objects(namespace).map { |m| member_heading(m) } +
          instance_method_objects(namespace).map { |m| member_heading(m) }
      end

      # A directly-`include`d module contributes its own constants,
      # attributes, and instance methods — not its own class methods
      # (`def self.foo` on a module stays solely on the module; `include`
      # never brings those along).
      def include_roster_lines(own)
        object.mixins(:instance).filter_map do |mod|
          next nil if mod.is_a?(::YARD::CodeObjects::Proxy)
          headings = (include_headings(mod) - own).sort
          headings.empty? ? nil : roster_line("Included from", mod, headings)
        end
      end

      def include_headings(namespace)
        constant_objects(namespace).map { |c| c.name.to_s } +
          instance_attribute_objects(namespace).map { |a| "##{a.name}" } +
          instance_method_objects(namespace).map { |m| member_heading(m) }
      end

      # A directly-`extend`ed module's own attributes/instance methods
      # become the extending object's class-level members ({CrossReferencing
      # extends_line}'s already-established semantics) — sigil built as
      # `.name` by hand, not via {MethodSignature#member_heading} (which
      # would read the module's own, genuinely-instance, `#scope` and give
      # `#name`). No constants (`extend` doesn't affect constant lookup) and
      # no class methods (same reasoning as `include`, above).
      #
      # Skips a self-`extend`ed module (`extend self`): YARD never
      # synthesizes a trustworthy class-scope `MethodObject` for that case
      # (probed directly — `meths(scope: :class, included: true)` returns
      # the *same*, instance-scoped object with its `#scope` transiently
      # misreported, not a distinct one safe to build a heading from), and
      # the "`extend self` / `module_function`" decision already settled on
      # not fabricating a second listing for it — metadata-only, matching
      # YARD's own default HTML template.
      def extend_roster_lines(own)
        object.mixins(:class).filter_map do |mod|
          next nil if mod.is_a?(::YARD::CodeObjects::Proxy) || self_reference?(mod)
          headings = (extend_headings(mod) - own).sort
          headings.empty? ? nil : roster_line("Extended from", mod, headings)
        end
      end

      def extend_headings(namespace)
        instance_attribute_objects(namespace).map { |a| ".#{a.name}" } +
          instance_method_objects(namespace).map { |m| ".#{member_name(m)}" }
      end

      def roster_line(verb, mod, headings)
        names = headings.map { |h| "`#{h}`" }.join(", ")
        "- **#{verb} [`#{mod.name}`](#{link_path(mod)}):** #{names}"
      end
    end
  end
end
