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
      # @param overload [::YARD::Tags::OverloadTag, nil] when given, render
      #   this overload's own parameter list instead of +meth+'s real one
      #   (see {#signature_text})
      # @return [Array<String>] each parameter as it should appear in the
      #   signature, e.g. `"to"`, `"to = DEFAULT_ELAPSED"`, or `"b: 1"` for
      #   an optional keyword arg (YARD includes the trailing `:` in the
      #   name itself, so a keyword default reads `name: default`, not
      #   `name: = default`)
      #
      def param_names(meth, overload: nil)
        (overload || meth).parameters.map do |name, default|
          next name.to_s unless default
          name.end_with?(":") ? "#{name} #{default}" : "#{name} = #{default}"
        end
      end

      ##
      # @param meth [::YARD::CodeObjects::MethodObject]
      # @return [String, nil] the object's own name for the synthetic `.new`
      #   entry (constructors have no real `@return` type of their own), or
      #   every type from every declared `@return` tag, comma-joined (a
      #   single tag's own union type and multiple `@return` tags render
      #   identically here — both are just "more than one type token")
      #
      def signature_return_type(meth)
        return object.name.to_s if meth.constructor?
        types = meth.tags(:return).flat_map { |tag| tag.types || [] }
        types.empty? ? nil : types.join(", ")
      end

      ##
      # @param meth [::YARD::CodeObjects::MethodObject]
      # @return [::YARD::Tags::Tag, nil] the method's `@yield` tag, if any
      #
      def yield_tag(meth)
        meth.tag(:yield)
      end

      ##
      # Whether a method takes a block only implicitly (bare `yield`, no
      # `&block`-named parameter): true when it's documented with any of the
      # `@yield`/`@yieldparam`/`@yieldreturn` family but doesn't capture the
      # block as a named parameter. A captured `&block` param is already
      # visible in {#param_names}, so only the uncaptured case needs a
      # synthetic marker in the signature line (see {#block_literal}).
      #
      # @param meth [::YARD::CodeObjects::MethodObject]
      # @return [Boolean]
      #
      def implicit_block?(meth)
        return false if meth.parameters.any? { |name, _| name.to_s.start_with?("&") }
        !(yield_tag(meth).nil? && meth.tags(:yieldparam).empty? && meth.tag(:yieldreturn).nil?)
      end

      ##
      # The block's parameter names for {#block_literal}, preferring the
      # structured `@yieldparam` tags (in declaration order) and falling
      # back to `@yield`'s own bracketed name list (`@yield [a, b] ...`)
      # when there's no `@yieldparam`.
      #
      # @param meth [::YARD::CodeObjects::MethodObject]
      # @return [Array<String>]
      #
      def block_param_names(meth)
        yieldparams = meth.tags(:yieldparam)
        return yieldparams.map(&:name) unless yieldparams.empty?
        yield_tag(meth)&.types || []
      end

      ##
      # @param meth [::YARD::CodeObjects::MethodObject]
      # @return [String, nil] a block-literal signature fragment, e.g.
      #   `{ |item| ... }` or `{ ... }`, for a method that takes a block only
      #   implicitly (see {#implicit_block?}); `nil` for a method with no
      #   block at all, or one that captures it as a named `&block` param
      #   (already covered by {#param_names} instead)
      #
      def block_literal(meth)
        return nil unless implicit_block?(meth)
        names = block_param_names(meth)
        names.empty? ? "{ ... }" : "{ |#{names.join(', ')}| ... }"
      end

      ##
      # @param meth [::YARD::CodeObjects::MethodObject]
      # @param params [Array<String>] as returned by {#param_names}
      # @return [Boolean] whether +meth+ should render in infix operator form
      #   (`point + other`) rather than dotted call form (`point.+(other)`)
      #
      def infix_call?(meth, params)
        !meth.constructor? && operator?(meth) && meth.scope == :instance && params.size == 1
      end

      ##
      # @param meth [::YARD::CodeObjects::MethodObject]
      # @param overload [::YARD::Tags::OverloadTag, nil] when given, this
      #   overload's own `@return` instead of +meth+'s real one (see
      #   {#signature_text})
      # @return [String, nil]
      #
      def signature_return_type_for(meth, overload)
        return overload.tag(:return)&.types&.first if overload
        signature_return_type(meth)
      end

      ##
      # @param meth [::YARD::CodeObjects::MethodObject]
      # @param overload [::YARD::Tags::OverloadTag, nil] when given, render
      #   this `@overload` tag's own params/return instead of +meth+'s real
      #   ones — used for a method documented via one or more `@overload`
      #   tags, whose actual Ruby signature (e.g. `def of(*args)`) doesn't
      #   reflect how it's meant to be called
      # @return [String] the natural-call-syntax signature line, e.g.
      #   `Point.parse(str) → Point` or `point + other → Point`
      #
      def signature_text(meth, overload: nil)
        name = member_name(meth)
        params = param_names(meth, overload: overload)
        block = block_literal(meth)
        call =
          if infix_call?(meth, params)
            "#{receiver_name(meth)} #{name} #{params.first}"
          else
            base = "#{receiver_name(meth)}.#{name}"
            base += "(#{params.join(', ')})" unless params.empty? && block
            block ? "#{base} #{block}" : base
          end
        return_type = signature_return_type_for(meth, overload)
        return_type ? "#{call} → #{return_type}" : call
      end

      ##
      # @param meth [::YARD::CodeObjects::MethodObject]
      # @return [Array<::YARD::Tags::Tag>] the method's `@return` tags,
      #   except for a constructor, which is always treated as having
      #   none — YARD auto-synthesizes a `@return` tag on `#initialize`
      #   even when none was written, and the synthetic `.new` entry
      #   already gets its return type from {#signature_return_type}
      #   instead
      #
      def method_return_tags(meth)
        meth.constructor? ? [] : meth.tags(:return)
      end
    end
  end
end
