# frozen_string_literal: true

require "helper"

describe ::YARD::AgentDocs::MethodSignature do
  let(:holder) do
    source = <<~RUBY
      class Point
        # @param x [Integer]
        # @param y [Integer]
        def initialize(x, y)
        end

        # @param str [String]
        # @return [Point]
        def self.parse(str)
        end

        # @param other [Point]
        # @return [Point]
        def +(other)
        end

        # @return [Float]
        def distance_to(other)
        end

        def reset(to = 0)
        end

        def sum(*values)
        end

        def required_kw(a:)
        end

        def optional_kw(b: 1)
        end

        def double_splat(**opts)
        end

        def no_return_value
        end

        # @return [String] the first shape
        # @return [nil] the second shape
        def multi_return
        end

        # @return [String, nil]
        def union_return
        end

        # @overload of(x, y)
        #   @param x [Integer]
        #   @param y [Integer]
        #   @return [Point]
        # @overload of(count)
        #   @param count [Integer]
        #   @return [Array<Point>]
        def self.of(*args)
        end

        # @param index [Integer]
        # @return [Integer]
        def [](index)
        end

        # @param index [Integer]
        # @param value [Integer]
        def []=(index, value)
        end

        # @return [Point]
        def -@
        end

        def label=(value)
        end

        # @return [Boolean]
        def ==(other)
        end
      end
    RUBY
    agentdocs_holder(
      ::YARD::AgentDocs::MethodSignature, ::YARD::AgentDocs::CrossReferencing, source: source, at: "Point"
    )
  end

  def meth(name)
    holder.object.meths(inherited: false).find { |m| m.name.to_s == name.to_s }
  end

  def overload(name, index)
    meth(name).tags(:overload)[index]
  end

  # Parses +source+ into a fresh registry and returns a holder whose
  # +object+ is +path+ — for describe blocks that need their own,
  # differently-shaped source rather than the shared Point fixture above.
  def holder_for(source, path)
    agentdocs_holder(::YARD::AgentDocs::MethodSignature, ::YARD::AgentDocs::CrossReferencing, source: source, at: path)
  end

  describe "#operator?" do
    it "is true for an operator method name" do
      assert(holder.operator?(meth(:+)))
    end

    it "is false for an ordinary method name" do
      refute(holder.operator?(meth(:distance_to)))
    end
  end

  describe "#member_name" do
    it "is 'new' for the constructor" do
      assert_equal("new", holder.member_name(meth(:initialize)))
    end

    it "is the method's own name otherwise" do
      assert_equal("distance_to", holder.member_name(meth(:distance_to)))
    end
  end

  describe "#class_level?" do
    it "is true for the constructor" do
      assert(holder.class_level?(meth(:initialize)))
    end

    it "is true for a class method" do
      assert(holder.class_level?(meth(:parse)))
    end

    it "is false for an instance method" do
      refute(holder.class_level?(meth(:distance_to)))
    end
  end

  describe "#member_heading" do
    it "prefixes the constructor with '.'" do
      assert_equal(".new", holder.member_heading(meth(:initialize)))
    end

    it "prefixes a class method with '.'" do
      assert_equal(".parse", holder.member_heading(meth(:parse)))
    end

    it "prefixes an instance method with '#'" do
      assert_equal("#distance_to", holder.member_heading(meth(:distance_to)))
    end
  end

  describe "#receiver_name" do
    it "is the object's own name for a class-level member" do
      assert_equal("Point", holder.receiver_name(meth(:parse)))
    end

    it "is the object's downcased name for an instance-level member" do
      assert_equal("point", holder.receiver_name(meth(:distance_to)))
    end
  end

  describe "#param_names" do
    it "renders required params by name only" do
      assert_equal(["x", "y"], holder.param_names(meth(:initialize)))
    end

    it "renders an optional param with its default value" do
      assert_equal(["to = 0"], holder.param_names(meth(:reset)))
    end

    it "renders a splat param with its sigil intact" do
      assert_equal(["*values"], holder.param_names(meth(:sum)))
    end

    it "renders a required keyword param with its trailing colon and no default" do
      assert_equal(["a:"], holder.param_names(meth(:required_kw)))
    end

    it "renders an optional keyword param as 'name: default', not 'name: = default'" do
      assert_equal(["b: 1"], holder.param_names(meth(:optional_kw)))
    end

    it "renders a double-splat param with its sigil intact" do
      assert_equal(["**opts"], holder.param_names(meth(:double_splat)))
    end

    it "renders an overload's own params when given, ignoring the real method's" do
      assert_equal(["x", "y"], holder.param_names(meth(:of), overload: overload(:of, 0)))
      assert_equal(["count"], holder.param_names(meth(:of), overload: overload(:of, 1)))
    end
  end

  describe "#signature_return_type" do
    it "is the object's own name for the constructor" do
      assert_equal("Point", holder.signature_return_type(meth(:initialize)))
    end

    it "is the method's declared @return type" do
      assert_equal("Float", holder.signature_return_type(meth(:distance_to)))
    end

    it "is nil when there is no @return tag" do
      assert_nil(holder.signature_return_type(meth(:no_return_value)))
    end

    it "joins every type from every @return tag when there is more than one" do
      assert_equal("String, nil", holder.signature_return_type(meth(:multi_return)))
    end

    it "joins every type within a single @return tag's own union type" do
      assert_equal("String, nil", holder.signature_return_type(meth(:union_return)))
    end
  end

  describe "#assignment_call?" do
    it "is true for an explicit name= method not paired via attr_*" do
      assert(holder.assignment_call?(meth(:label=)))
    end

    it "is false for a comparison operator that happens to end in =" do
      refute(holder.assignment_call?(meth(:==)))
    end

    it "is false for #[]=, already handled by #bracket_call?" do
      refute(holder.assignment_call?(meth(:[]=)))
    end

    it "is false for the constructor" do
      refute(holder.assignment_call?(meth(:initialize)))
    end

    it "is true at class scope too, not just instance scope" do
      holder = holder_for(<<~RUBY, "Widget")
        class Widget
          def self.target=(value)
          end
        end
      RUBY
      assert(holder.assignment_call?(holder.object.meths.find { |m| m.name.to_s == "target=" }))
    end
  end

  describe "#signature_text" do
    it "renders the synthetic constructor entry using the class's own name" do
      assert_equal("Point.new(x, y) → Point", holder.signature_text(meth(:initialize)))
    end

    it "renders a class method in dotted call form" do
      assert_equal("Point.parse(str) → Point", holder.signature_text(meth(:parse)))
    end

    it "renders a one-argument operator method in infix form" do
      assert_equal("point + other → Point", holder.signature_text(meth(:+)))
    end

    it "renders an ordinary instance method in dotted call form" do
      assert_equal("point.distance_to(other) → Float", holder.signature_text(meth(:distance_to)))
    end

    it "omits the arrow when there is no return type" do
      assert_equal("point.no_return_value()", holder.signature_text(meth(:no_return_value)))
    end

    it "renders using the given overload's params and return type instead of the real method's" do
      assert_equal("Point.of(x, y) → Point", holder.signature_text(meth(:of), overload: overload(:of, 0)))
      assert_equal("Point.of(count) → Array<Point>", holder.signature_text(meth(:of), overload: overload(:of, 1)))
    end

    it "renders a #[] method in bracket form" do
      assert_equal("point[index] → Integer", holder.signature_text(meth(:[])))
    end

    it "renders a #[]= method in bracket-assignment form, with no arrow" do
      assert_equal("point[index] = value", holder.signature_text(meth(:[]=)))
    end

    it "renders a unary operator method in prefix form" do
      assert_equal("-point → Point", holder.signature_text(meth(:-@)))
    end

    it "renders an explicit name= method in plain assignment form, with no arrow" do
      assert_equal("point.label = value", holder.signature_text(meth(:label=)))
    end

    it "renders a comparison operator ending in = in infix form, not assignment form" do
      assert_equal("point == other → Boolean", holder.signature_text(meth(:==)))
    end

    it "renders a class-scoped name= method against the class receiver" do
      holder = holder_for(<<~RUBY, "Widget")
        class Widget
          def self.target=(value)
          end
        end
      RUBY
      meth = holder.object.meths.find { |m| m.name.to_s == "target=" }
      assert_equal("Widget.target = value", holder.signature_text(meth))
    end
  end

  describe "#method_return_tags" do
    it "is empty for the constructor even if YARD synthesized a @return tag" do
      assert(meth(:initialize).tag(:return), "expected YARD to synthesize a @return tag on the constructor")
      assert_empty(holder.method_return_tags(meth(:initialize)))
    end

    it "is the method's own @return tag otherwise" do
      assert_equal(["Float"], holder.method_return_tags(meth(:distance_to)).map { |t| t.types.first })
    end

    it "is empty when there is no @return tag" do
      assert_empty(holder.method_return_tags(meth(:no_return_value)))
    end

    it "includes every @return tag when there is more than one" do
      assert_equal(["String", "nil"], holder.method_return_tags(meth(:multi_return)).map { |t| t.types.first })
    end
  end

  describe "#signature_return_type_for" do
    it "uses the given overload's own @return type" do
      assert_equal("Point", holder.signature_return_type_for(meth(:of), overload(:of, 0)))
      assert_equal("Array<Point>", holder.signature_return_type_for(meth(:of), overload(:of, 1)))
    end

    it "falls back to #signature_return_type when no overload is given" do
      assert_equal("Float", holder.signature_return_type_for(meth(:distance_to), nil))
    end
  end

  describe "alias handling" do
    let(:holder) do
      holder_for(<<~RUBY, "Greeter")
        class Greeter
          # Says hello.
          def greet
          end
          alias hi greet

          # Extra alias commentary.
          alias_method :hey, :greet

          def unaliased
          end
        end
      RUBY
    end

    describe "#alias_original" do
      it "is nil for a non-alias method" do
        assert_nil(holder.alias_original(meth(:greet)))
      end

      it "resolves an `alias` keyword target" do
        assert_equal(meth(:greet), holder.alias_original(meth(:hi)))
      end

      it "resolves an `alias_method` target" do
        assert_equal(meth(:greet), holder.alias_original(meth(:hey)))
      end
    end

    describe "#alias_own_prose" do
      it "is nil for a non-alias method" do
        assert_nil(holder.alias_own_prose(meth(:greet)))
      end

      it "is nil when the alias adds no text of its own" do
        assert_nil(holder.alias_own_prose(meth(:hi)))
      end

      it "is just the alias's own added prose, with the original's prose stripped as a prefix" do
        assert_equal("Extra alias commentary.", holder.alias_own_prose(meth(:hey)))
      end
    end

    describe "#also_known_as_line" do
      it "is nil when the method has no aliases" do
        assert_nil(holder.also_known_as_line(meth(:unaliased)))
      end

      it "comma-joins every alias" do
        assert_equal("* **Also known as:** `#hi`, `#hey`", holder.also_known_as_line(meth(:greet)))
      end
    end
  end

  describe "#overridden_method and #overrides_line" do
    let(:source) do
      <<~RUBY
        class Shape
          # The shape's label.
          def label
          end
        end

        class Rect < Shape
          def label
          end
        end

        class Polygon < Shape
        end

        class Triangle < Polygon
          def label
          end
        end

        class Square < Shape
          # Square's own label.
          def label
          end
        end

        class UndocBase
        end

        class UndocSub < UndocBase
          def label
          end
        end
      RUBY
    end

    def label_meth(holder)
      holder.object.meths(inherited: false).find { |m| m.name.to_s == "label" }
    end

    it "finds the ancestor across one superclass hop" do
      holder = holder_for(source, "Rect")
      meth = label_meth(holder)
      ancestor = holder.overridden_method(meth)
      assert_equal("Shape", ancestor.namespace.name.to_s)
      assert_equal("* **Overrides:** [`Shape#label`](Shape.md)", holder.overrides_line(meth))
    end

    it "finds the ancestor across two superclass hops" do
      holder = holder_for(source, "Triangle")
      meth = label_meth(holder)
      ancestor = holder.overridden_method(meth)
      assert_equal("Shape", ancestor.namespace.name.to_s)
      assert_equal("* **Overrides:** [`Shape#label`](Shape.md)", holder.overrides_line(meth))
    end

    it "is nil when the method documents itself" do
      holder = holder_for(source, "Square")
      meth = label_meth(holder)
      assert_nil(holder.overridden_method(meth))
      assert_nil(holder.overrides_line(meth))
    end

    it "is nil when no ancestor documents the method" do
      holder = holder_for(source, "UndocSub")
      meth = label_meth(holder)
      assert_nil(holder.overridden_method(meth))
      assert_nil(holder.overrides_line(meth))
    end
  end

  describe "block-taking methods" do
    let(:holder) do
      holder_for(<<~RUBY, "Runner")
        class Runner
          # @yield [item] one call per item
          def each_bare
          end

          # @yield [ignored] use yieldparam name instead
          # @yieldparam item [String] each item
          def each_typed
          end

          # @yield [x] called for each
          def each_captured(&block)
          end

          def no_block
          end
        end
      RUBY
    end

    describe "#implicit_block?" do
      it "is true for a bare @yield with bracketed names" do
        assert(holder.implicit_block?(meth(:each_bare)))
      end

      it "is true when @yieldparam tags are present" do
        assert(holder.implicit_block?(meth(:each_typed)))
      end

      it "is false when the block is captured as a named &block param" do
        refute(holder.implicit_block?(meth(:each_captured)))
      end

      it "is false for a method with no block at all" do
        refute(holder.implicit_block?(meth(:no_block)))
      end
    end

    describe "#block_param_names" do
      it "reads @yield's own bracketed name list when there's no @yieldparam" do
        assert_equal(["item"], holder.block_param_names(meth(:each_bare)))
      end

      it "prefers @yieldparam names over @yield's own bracket list" do
        assert_equal(["item"], holder.block_param_names(meth(:each_typed)))
      end
    end

    describe "#block_literal" do
      it "renders a block literal with the yielded param names for an implicit block" do
        assert_equal("{ |item| ... }", holder.block_literal(meth(:each_bare)))
      end

      it "is nil when the block is captured as a named &block param" do
        assert_nil(holder.block_literal(meth(:each_captured)))
      end

      it "is nil for a method with no block at all" do
        assert_nil(holder.block_literal(meth(:no_block)))
      end
    end
  end

  describe "#ordered_param_tags" do
    it "reorders tags to match the real, signature parameter order regardless of docstring order" do
      holder = holder_for(<<~RUBY, "Foo")
        class Foo
          # @param y [Integer]
          # @param x [Integer]
          def reordered(x, y)
          end
        end
      RUBY
      meth = holder.object.meths(inherited: false).find { |m| m.name.to_s == "reordered" }
      ordered = holder.ordered_param_tags(meth, meth.tags(:param))
      assert_equal(["x", "y"], ordered.map(&:name))
    end

    it "drops tags naming a nonexistent parameter, keeping real ones in signature order" do
      # The out-of-sync `seconds`/`millis` tags are the whole point of this
      # example, and YARD logs a `[warn]` for each one while parsing. Quieted
      # to ERROR (not FATAL) so a genuine parse failure would still surface.
      holder = log.enter_level(::YARD::Logger::ERROR) do
        holder_for(<<~RUBY, "Foo")
          class Foo
            # @param to [Integer]
            # @param seconds [Integer]
            # @param millis [Integer]
            def reset(to)
            end
          end
        RUBY
      end
      meth = holder.object.meths(inherited: false).find { |m| m.name.to_s == "reset" }
      ordered = holder.ordered_param_tags(meth, meth.tags(:param))
      assert_equal(["to"], ordered.map(&:name))
    end

    it "normalizes splat/double-splat sigils when matching tag names to real param names" do
      holder = holder_for(<<~RUBY, "Foo")
        class Foo
          # @param opts [Hash]
          # @param values [Array]
          def variadic(*values, **opts)
          end
        end
      RUBY
      meth = holder.object.meths(inherited: false).find { |m| m.name.to_s == "variadic" }
      ordered = holder.ordered_param_tags(meth, meth.tags(:param))
      assert_equal(["values", "opts"], ordered.map(&:name))
    end

    it "normalizes a trailing keyword-argument colon when matching tag names to real param names" do
      holder = holder_for(<<~RUBY, "Foo")
        class Foo
          # @param b [String]
          # @param a [Integer]
          def kw_reordered(a:, b:)
          end
        end
      RUBY
      meth = holder.object.meths(inherited: false).find { |m| m.name.to_s == "kw_reordered" }
      ordered = holder.ordered_param_tags(meth, meth.tags(:param))
      assert_equal(["a", "b"], ordered.map(&:name))
    end
  end
end
