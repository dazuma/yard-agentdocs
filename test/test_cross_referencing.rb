# frozen_string_literal: true

require "helper"

describe ::YARD::AgentDocs::CrossReferencing do
  let(:holder_class) do
    Class.new do
      include ::YARD::AgentDocs::CrossReferencing

      attr_accessor :object
    end
  end

  # Parses +source+ into a fresh registry and returns a holder whose
  # +object+ is the code object at +current_path+, mirroring how a template
  # sees the object currently being rendered.
  def holder_for(source, current_path)
    ::YARD::Registry.clear
    ::YARD.parse_string(source)
    holder = holder_class.new
    holder.object = ::YARD::Registry.at(current_path)
    holder
  end

  describe "#type_ref" do
    it "returns an empty string for a nil or empty type name" do
      holder = holder_for("class Foo; end", "Foo")
      assert_equal("", holder.type_ref(nil))
      assert_equal("", holder.type_ref(""))
    end

    it "renders an unresolved simple type as a plain backtick" do
      holder = holder_for("class Foo; end", "Foo")
      assert_equal("`Bogus`", holder.type_ref("Bogus"))
    end

    it "renders a self-reference as a plain backtick, not a link" do
      holder = holder_for("class Foo; end", "Foo")
      assert_equal("`Foo`", holder.type_ref("Foo"))
    end

    it "renders a resolved simple type as a markdown link" do
      holder = holder_for(<<~RUBY, "Foo::Bar")
        module Foo
          class Baz; end
          class Bar; end
        end
      RUBY
      assert_equal("[`Baz`](Baz.md)", holder.type_ref("Baz"))
    end

    it "links only the resolvable name inside a compound type, keeping punctuation inside backtick spans" do
      holder = holder_for(<<~RUBY, "Foo::Bar")
        module Foo
          class Baz; end
          class Bar; end
        end
      RUBY
      assert_equal("`Array<`[`Baz`](Baz.md)`>`", holder.type_ref("Array<Baz>"))
    end

    it "collapses to a single backtick span when nothing in a compound type resolves" do
      holder = holder_for("class Foo; end", "Foo")
      assert_equal("`Array<Bogus>`", holder.type_ref("Array<Bogus>"))
    end

    it "links multiple resolvable names within one compound type" do
      holder = holder_for(<<~RUBY, "Foo::Bar")
        module Foo
          class Baz; end
          class Bar; end
        end
      RUBY
      assert_equal(
        "`Hash{`[`Baz`](Baz.md)` => `[`Baz`](Baz.md)`}`",
        holder.type_ref("Hash{Baz => Baz}")
      )
    end

    it "never resolves a duck-type reference to a link" do
      holder = holder_for("class Foo; end", "Foo")
      assert_equal("`#to_s`", holder.type_ref("#to_s"))
    end

    it "leaves a duck-type reference untouched inside a compound type" do
      holder = holder_for(<<~RUBY, "Foo::Bar")
        module Foo
          class Baz; end
          class Bar; end
        end
      RUBY
      assert_equal("`Array<`[`Baz`](Baz.md)`, #to_s>`", holder.type_ref("Array<Baz, #to_s>"))
    end
  end

  describe "#see_ref" do
    it "renders an unresolved @see target as a plain backtick" do
      holder = holder_for(<<~RUBY, "Foo")
        # @see Bogus
        class Foo; end
      RUBY
      tag = holder.object.tag(:see)
      assert_equal("`Bogus`", holder.see_ref(tag))
    end

    it "renders a @see target owned by the object currently being rendered as a plain backtick" do
      holder = holder_for(<<~RUBY, "Foo")
        class Foo
          # @see bar
          def foo; end

          def bar; end
        end
      RUBY
      tag = holder.object.meths.find { |m| m.name == :foo }.tag(:see)
      assert_equal("`bar`", holder.see_ref(tag))
    end

    it "renders a @see target in another file as a markdown link" do
      holder = holder_for(<<~RUBY, "Foo::Bar")
        module Foo
          class Baz
            def qux; end
          end

          # @see Baz#qux
          class Bar; end
        end
      RUBY
      tag = holder.object.tag(:see)
      assert_equal("[`Baz#qux`](Baz.md)", holder.see_ref(tag))
    end
  end

  describe "#link_path" do
    it "returns a path relative to the currently-rendered object's own file" do
      holder = holder_for(<<~RUBY, "Foo::Bar")
        module Foo
          class Baz; end
          class Bar; end
        end
      RUBY
      target = ::YARD::Registry.at("Foo::Baz")
      assert_equal("Baz.md", holder.link_path(target))
    end

    it "walks up out of a nested namespace to reach a sibling's file" do
      holder = holder_for(<<~RUBY, "Foo::Bar::Nested")
        module Foo
          class Target; end

          class Bar
            class Nested; end
          end
        end
      RUBY
      target = ::YARD::Registry.at("Foo::Target")
      assert_equal("../Target.md", holder.link_path(target))
    end

    it "resolves a method target to its owning namespace's file" do
      holder = holder_for(<<~RUBY, "Foo::Bar")
        module Foo
          class Baz
            def qux; end
          end

          class Bar; end
        end
      RUBY
      target = ::YARD::Registry.at("Foo::Baz#qux")
      assert_equal("Baz.md", holder.link_path(target))
    end
  end
end
