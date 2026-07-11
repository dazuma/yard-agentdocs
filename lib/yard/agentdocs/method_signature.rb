# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # Method-signature formatting shared by the `module`/`class` `agentdocs`
    # templates: deciding how a method is addressed (`.name`/`#name`) and
    # rendering its natural-call-syntax signature line, e.g.
    # `point.distance_to(other) → Float` or, for a binary operator,
    # `point + other → Point`.
    #
    # Requires the including template to provide an `object` method
    # returning the `YARD::CodeObjects::NamespaceObject` currently being
    # rendered, as `YARD::Templates::Template` already does.
    #
    module MethodSignature
      ##
      # Method names rendered in infix form (`point + other`) rather than
      # dotted call form (`point.send(other)`), when they take exactly one
      # argument.
      #
      OPERATOR_METHOD_NAMES = [
        "+", "-", "*", "/", "%", "**", "==", "!=", "<=>", "<", ">", "<=", ">=",
        "<<", ">>", "&", "|", "^", "~", "!", "[]", "[]=", "=~", "+@", "-@"
      ].freeze

      ##
      # @param meth [::YARD::CodeObjects::MethodObject]
      # @return [Boolean]
      #
      def operator?(meth)
        OPERATOR_METHOD_NAMES.include?(meth.name.to_s)
      end

      ##
      # The display name for a member: the constructor is always shown as
      # `new` (documenting `#initialize` under the synthetic `Class.new`
      # entry).
      #
      # @param meth [::YARD::CodeObjects::MethodObject]
      # @return [String]
      #
      def member_name(meth)
        meth.constructor? ? "new" : meth.name.to_s
      end

      ##
      # Whether a member is addressed with `.` (class-level, or the
      # constructor) or `#` (instance-level).
      #
      # @param meth [::YARD::CodeObjects::MethodObject]
      # @return [Boolean]
      #
      def class_level?(meth)
        meth.constructor? || meth.scope == :class
      end

      ##
      # @param meth [::YARD::CodeObjects::MethodObject]
      # @return [String] e.g. `.new` or `#distance_to`
      #
      def member_heading(meth)
        "#{class_level?(meth) ? '.' : '#'}#{member_name(meth)}"
      end

      ##
      # @param meth [::YARD::CodeObjects::MethodObject]
      # @return [String] the object's constant name for a class-level
      #   member, or a lowercased receiver name for an instance-level one
      #
      def receiver_name(meth)
        class_level?(meth) ? object.name.to_s : object.name.to_s.downcase
      end

      ##
      # @param meth [::YARD::CodeObjects::MethodObject]
      # @return [Array<String>] each parameter as it should appear in the
      #   signature, e.g. `"to"` or `"to = DEFAULT_ELAPSED"`
      #
      def param_names(meth)
        meth.parameters.map { |name, default| default ? "#{name} = #{default}" : name.to_s }
      end

      ##
      # @param meth [::YARD::CodeObjects::MethodObject]
      # @return [String, nil] the object's own name for the synthetic `.new`
      #   entry (constructors have no real `@return` type of their own), or
      #   the method's declared `@return` type otherwise
      #
      def signature_return_type(meth)
        return object.name.to_s if meth.constructor?
        tag = meth.tag(:return)
        tag&.types&.first
      end

      ##
      # @param meth [::YARD::CodeObjects::MethodObject]
      # @return [String] the natural-call-syntax signature line, e.g.
      #   `Point.parse(str) → Point` or `point + other → Point`
      #
      def signature_text(meth)
        name = member_name(meth)
        params = param_names(meth)
        call =
          if !meth.constructor? && operator?(meth) && meth.scope == :instance && params.size == 1
            "#{receiver_name(meth)} #{name} #{params.first}"
          else
            "#{receiver_name(meth)}.#{name}(#{params.join(', ')})"
          end
        return_type = signature_return_type(meth)
        return_type ? "#{call} → #{return_type}" : call
      end

      ##
      # @param meth [::YARD::CodeObjects::MethodObject]
      # @return [::YARD::Tags::Tag, nil] the method's `@return` tag, except
      #   for a constructor, which is always treated as having none — YARD
      #   auto-synthesizes a `@return` tag on `#initialize` even when none
      #   was written, and the synthetic `.new` entry already gets its
      #   return type from {#signature_return_type} instead
      #
      def method_return_tag(meth)
        meth.constructor? ? nil : meth.tag(:return)
      end
    end
  end
end
