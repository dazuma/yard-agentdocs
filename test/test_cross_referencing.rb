# frozen_string_literal: true

require "helper"

describe ::YARD::AgentDocs::CrossReferencing do
  # Parses +source+ into a fresh registry and returns a holder whose
  # +object+ is the code object at +current_path+, mirroring how a template
  # sees the object currently being rendered.
  def holder_for(source, current_path)
    agentdocs_holder(::YARD::AgentDocs::CrossReferencing, source: source, at: current_path)
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

    it "collapses a Hash compound type to a single backtick span when nothing resolves" do
      holder = holder_for("class Foo; end", "Foo")
      assert_equal("`Hash{Symbol => Numeric}`", holder.type_ref("Hash{Symbol => Numeric}"))
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

  describe "#type_ref_first" do
    it "returns an empty string for a nil tag" do
      holder = holder_for("class Foo; end", "Foo")
      assert_equal("", holder.type_ref_first(nil))
    end

    it "returns an empty string for a tag with no declared types" do
      holder = holder_for(<<~RUBY, "Foo")
        class Foo
          # @return
          def bar; end
        end
      RUBY
      tag = holder.object.meths.find { |m| m.name == :bar }.tag(:return)
      assert_equal("", holder.type_ref_first(tag))
    end

    it "renders every type of a tag declaring multiple types, comma-joined" do
      holder = holder_for(<<~RUBY, "Foo::Bar")
        module Foo
          class Baz; end
          class Bar
            # @return [Baz, String]
            def qux; end
          end
        end
      RUBY
      tag = holder.object.meths.find { |m| m.name == :qux }.tag(:return)
      assert_equal("[`Baz`](Baz.md)`, String`", holder.type_ref_first(tag))
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

  describe "#resolve_references" do
    it "returns text with no braces unchanged" do
      holder = holder_for("class Foo; end", "Foo")
      assert_equal("Plain prose, no references.", holder.resolve_references("Plain prose, no references."))
    end

    it "renders a resolved bare reference in another file as a markdown link" do
      holder = holder_for(<<~RUBY, "Foo::Bar")
        module Foo
          class Baz; end
          class Bar; end
        end
      RUBY
      assert_equal("See [`Baz`](Baz.md) for details.", holder.resolve_references("See {Baz} for details."))
    end

    it "renders a resolved same-file self-reference as a plain backtick, not a link" do
      holder = holder_for(<<~RUBY, "Foo")
        class Foo
          def bar; end
        end
      RUBY
      assert_equal("See `#bar` for details.", holder.resolve_references("See {#bar} for details."))
    end

    it "renders a resolved labeled reference in another file as a markdown link with the label as text" do
      holder = holder_for(<<~RUBY, "Foo::Bar")
        module Foo
          class Baz; end
          class Bar; end
        end
      RUBY
      assert_equal(
        "See [the Baz class](Baz.md) for details.",
        holder.resolve_references("See {Baz the Baz class} for details.")
      )
    end

    it "renders a labeled same-file self-reference as the plain label text, with no backticks or link" do
      holder = holder_for(<<~RUBY, "Foo")
        class Foo
          def bar; end
        end
      RUBY
      assert_equal(
        "Call the bar method for details.",
        holder.resolve_references("Call {#bar the bar method} for details.")
      )
    end

    it "leaves an unresolved bare reference completely untouched" do
      holder = holder_for("class Foo; end", "Foo")
      assert_equal("See {Bogus} for details.", holder.resolve_references("See {Bogus} for details."))
    end

    it "leaves an unresolved labeled reference completely untouched" do
      holder = holder_for("class Foo; end", "Foo")
      assert_equal(
        "See {Bogus a label} for details.",
        holder.resolve_references("See {Bogus a label} for details.")
      )
    end

    it "strips a backslash escape without attempting resolution, even for an otherwise-resolvable name" do
      holder = holder_for(<<~RUBY, "Foo::Bar")
        module Foo
          class Baz; end
          class Bar; end
        end
      RUBY
      assert_equal("Not a link: {Baz}.", holder.resolve_references("Not a link: \\{Baz}."))
    end

    it "strips a bang escape without attempting resolution" do
      holder = holder_for(<<~RUBY, "Foo::Bar")
        module Foo
          class Baz; end
          class Bar; end
        end
      RUBY
      assert_equal("Not a link: {Baz}.", holder.resolve_references("Not a link: !{Baz}."))
    end

    it "leaves a reference inside a single-backtick code span untouched" do
      holder = holder_for(<<~RUBY, "Foo::Bar")
        module Foo
          class Baz; end
          class Bar; end
        end
      RUBY
      assert_equal("Literal: `{Baz}`.", holder.resolve_references("Literal: `{Baz}`."))
    end

    it "leaves a reference inside a fenced code block untouched" do
      holder = holder_for(<<~RUBY, "Foo::Bar")
        module Foo
          class Baz; end
          class Bar; end
        end
      RUBY
      text = "before\n```\n{Baz}\n```\nafter"
      assert_equal(text, holder.resolve_references(text))
    end

    it "resolves multiple references in the same text" do
      holder = holder_for(<<~RUBY, "Foo::Bar")
        module Foo
          class Baz; end
          class Bar; end
        end
      RUBY
      assert_equal(
        "[`Baz`](Baz.md) and [`Baz`](Baz.md) again.",
        holder.resolve_references("{Baz} and {Baz} again.")
      )
    end
  end

  describe "#resolve_references — {file:...} guide references" do
    # A minimal stand-in for `YARD::CodeObjects::ExtraFileObject`, exposing
    # only the three accessors {CrossReferencing#render_file_reference}
    # actually reads.
    def guide_fixture(filename, name, title)
      ::Struct.new(:filename, :name, :title).new(filename, name, title)
    end

    def holder_with_files(source, current_path, *files)
      holder = holder_for(source, current_path)
      holder.options = ::Struct.new(:files).new(files)
      holder
    end

    it "renders a resolved unlabeled file reference as a markdown link using the guide's title" do
      holder = holder_with_files("class Foo; end", "Foo", guide_fixture("guide.md", "guide", "The Guide"))
      assert_equal(
        "See [`The Guide`](file.guide.md) for details.",
        holder.resolve_references("See {file:guide.md} for details.")
      )
    end

    it "renders a resolved labeled file reference as a markdown link with the label as text" do
      holder = holder_with_files("class Foo; end", "Foo", guide_fixture("guide.md", "guide", "The Guide"))
      assert_equal(
        "See [the guide](file.guide.md) for details.",
        holder.resolve_references("See {file:guide.md the guide} for details.")
      )
    end

    it "leaves a file reference to an unregistered path completely untouched" do
      holder = holder_with_files("class Foo; end", "Foo")
      text = "See {file:missing.md} for details."
      assert_equal(text, holder.resolve_references(text))
    end

    it "computes a file reference's link relative to the currently-rendered object's own file" do
      holder = holder_with_files(<<~RUBY, "Foo::Bar", guide_fixture("guide.md", "guide", "The Guide"))
        module Foo
          class Bar; end
        end
      RUBY
      assert_equal("[`The Guide`](../file.guide.md)", holder.resolve_references("{file:guide.md}"))
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
