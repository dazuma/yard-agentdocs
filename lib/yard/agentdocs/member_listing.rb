# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # Member-listing queries shared by the `module`/`class` `agentdocs`
    # templates: which of a namespace's own nested modules/classes,
    # constants, attributes, and methods actually render, after YARD's own
    # visibility verifier (e.g. `--no-private`, `--no-protected`) is applied.
    # Every query besides {#nested_objects} takes an optional +namespace+
    # argument (default: the object currently being rendered) so
    # {MemberRoster} can reuse this same filtering logic against an
    # ancestor/mixin's own members.
    #
    # Requires the including template to provide `object` and `run_verifier`
    # (both, like `options`, already provided by
    # `YARD::Templates::Template`), plus {MethodSignature#member_name} (used
    # to sort method listings) and {MemberRoster#member_roster_lines} (used
    # by {#any_members?}).
    #
    module MemberListing
      ##
      # @return [Array<::YARD::CodeObjects::Base>] this object's own nested
      #   modules/classes, sorted by name
      #
      def nested_objects
        list = object.children.select { |c| [:module, :class].include?(c.type) }
        run_verifier(list).sort_by { |o| o.name.to_s }
      end

      ##
      # @param namespace [::YARD::CodeObjects::NamespaceObject]
      # @return [Array<::YARD::CodeObjects::ConstantObject>] +namespace+'s
      #   own constants, sorted by name
      #
      def constant_objects(namespace = object)
        list = namespace.constants(inherited: false, included: false)
        run_verifier(list).sort_by { |o| o.name.to_s }
      end

      ##
      # @param namespace [::YARD::CodeObjects::NamespaceObject]
      # @return [Array<Attribute>] +namespace+'s own attributes, sorted by
      #   name
      #
      def attribute_objects(namespace = object)
        entries = namespace.attributes[:instance].map do |name, rw|
          Attribute.new(name: name.to_s, read: rw[:read], write: rw[:write])
        end
        entries = entries.select { |a| run_verifier([a.source_method]).any? }
        entries.sort_by(&:name)
      end

      ##
      # @param namespace [::YARD::CodeObjects::NamespaceObject]
      # @return [Array<::YARD::CodeObjects::MethodObject>] +namespace+'s own
      #   class methods, sorted by {MethodSignature#member_name}
      #
      def class_method_objects(namespace = object)
        list = namespace.meths(inherited: false, included: false).select { |m| m.scope == :class }
        run_verifier(list).sort_by { |m| member_name(m) }
      end

      # Excludes both inherited (superclass) and mixed-in (`include`d module)
      # methods: a superclass's or directly-`include`d module's methods are
      # documented on their own page (and, for a mixin, pointed to via
      # `includes_line`), not duplicated here — see the "Mixin/inheritance
      # content strategy" decision in devdocs/DESIGN.md. `:inherited` is a
      # no-op for modules (they have no superclass) but real for classes,
      # since `ClassObject#meths` overrides the base
      # `NamespaceObject#meths` to add it.
      #
      # +namespace+ (default: the object currently being rendered) lets
      # {MemberRoster} reuse this same filtering logic against an
      # ancestor/mixin's own members.
      #
      # @param namespace [::YARD::CodeObjects::NamespaceObject]
      # @return [Array<::YARD::CodeObjects::MethodObject>] +namespace+'s own
      #   instance methods (excluding attribute readers/writers and the
      #   constructor), sorted by {MethodSignature#member_name}
      #
      def instance_method_objects(namespace = object)
        list = namespace.meths(inherited: false, included: false).select do |m|
          m.scope == :instance && !m.is_attribute? && !m.constructor?
        end
        run_verifier(list).sort_by { |m| member_name(m) }
      end

      ##
      # @return [Boolean] whether this object has any constants, attributes,
      #   class methods, or instance methods of its own to render
      #
      def any_member_sections?
        constant_objects.any? || attribute_objects.any? || class_method_objects.any? || instance_method_objects.any?
      end

      ##
      # @return [Boolean] whether this object has anything at all to render
      #   in its `## Member Summary` section — nested modules/classes, its
      #   own constants/attributes/methods, or a names-only inherited/mixin
      #   member roster line (see {MemberRoster})
      #
      def any_members?
        nested_objects.any? || any_member_sections? || member_roster_lines.any?
      end
    end
  end
end
