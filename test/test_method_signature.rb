# frozen_string_literal: true

require "helper"

describe ::YARD::AgentDocs::MethodSignature do
  let(:holder_class) do
    Class.new do
      include ::YARD::AgentDocs::MethodSignature

      attr_accessor :object
    end
  end

  # Parses +source+ (a class/module body) into a fresh registry and returns
  # a holder whose +object+ is +namespace_path+, mirroring how a template
  # sees the object currently being rendered.
  def holder_for(source, namespace_path)
    ::YARD::Registry.clear
    ::YARD.parse_string(source)
    holder = holder_class.new
    holder.object = ::YARD::Registry.at(namespace_path)
    holder
  end

  let(:holder) do
    holder_for(<<~RUBY, "Point")
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
      end
    RUBY
  end

  def meth(name)
    holder.object.meths(inherited: false).find { |m| m.name.to_s == name.to_s }
  end

  def overload(name, index)
    meth(name).tags(:overload)[index]
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
end
