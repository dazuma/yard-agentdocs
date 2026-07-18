# frozen_string_literal: true

require "helper"

describe ::YARD::AgentDocs::AuxiliaryTags do
  # Parses +source+ (a class body) into a fresh registry and returns a holder
  # (with {::YARD::AgentDocs::AuxiliaryTags} and its required mixins —
  # {::YARD::AgentDocs::VisibilityInfo}, {::YARD::AgentDocs::Markdownify},
  # {::YARD::AgentDocs::TextLayout}, {::YARD::AgentDocs::CrossReferencing} —
  # included) whose +object+ is the object at +path+, in that same
  # still-populated registry.
  def holder_at(source, path)
    agentdocs_holder(
      ::YARD::AgentDocs::AuxiliaryTags, ::YARD::AgentDocs::VisibilityInfo,
      ::YARD::AgentDocs::Markdownify, ::YARD::AgentDocs::TextLayout, ::YARD::AgentDocs::CrossReferencing,
      source: source, at: path, markup: :markdown
    )
  end

  describe "#annotation_lines" do
    it "is empty for an untagged object" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          def bar; end
        end
      RUBY
      assert_empty(holder.annotation_lines(holder.object))
    end

    it "renders a private-API line for @private" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @private
          def bar; end
        end
      RUBY
      assert_equal(["* **Private API.**"], holder.annotation_lines(holder.object))
    end

    it "renders a bare @deprecated with no trailing space" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @deprecated
          def bar; end
        end
      RUBY
      assert_equal(["* **Deprecated.**"], holder.annotation_lines(holder.object))
    end

    it "renders @deprecated with text" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @deprecated Use `#baz` instead.
          def bar; end
        end
      RUBY
      assert_equal(["* **Deprecated.** Use `#baz` instead."], holder.annotation_lines(holder.object))
    end

    it "renders @deprecated with a resolvable inline reference as a Markdown link" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @deprecated Use {Baz} instead.
          def bar; end
        end

        class Baz; end
      RUBY
      assert_equal(
        ["* **Deprecated.** Use [`Baz`](Baz.md) instead."],
        holder.annotation_lines(holder.object)
      )
    end

    it "renders a bare @abstract with no trailing space" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @abstract
          def bar; end
        end
      RUBY
      assert_equal(["* **Abstract.**"], holder.annotation_lines(holder.object))
    end

    it "renders @abstract with text" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @abstract Override in a subclass.
          def bar; end
        end
      RUBY
      assert_equal(["* **Abstract.** Override in a subclass."], holder.annotation_lines(holder.object))
    end

    it "renders a bare @note with no trailing space" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @note
          def bar; end
        end
      RUBY
      assert_equal(["* **Note:**"], holder.annotation_lines(holder.object))
    end

    it "renders @note with text" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @note Not thread-safe.
          def bar; end
        end
      RUBY
      assert_equal(["* **Note:** Not thread-safe."], holder.annotation_lines(holder.object))
    end

    it "renders every tag in Private API/Deprecated/Abstract/Note order regardless of source order" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @note Some note.
          # @abstract Some abstract text.
          # @deprecated Some deprecation text.
          # @private
          def bar; end
        end
      RUBY
      assert_equal(
        [
          "* **Private API.**",
          "* **Deprecated.** Some deprecation text.",
          "* **Abstract.** Some abstract text.",
          "* **Note:** Some note.",
        ],
        holder.annotation_lines(holder.object)
      )
    end
  end

  describe "#trailing_annotation_lines" do
    it "is empty for an untagged object" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          def bar; end
        end
      RUBY
      assert_empty(holder.trailing_annotation_lines(holder.object))
    end

    it "renders @todo" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @todo Support more cases.
          def bar; end
        end
      RUBY
      assert_equal(["* **Todo:** Support more cases."], holder.trailing_annotation_lines(holder.object))
    end

    it "renders @since" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @since 1.0.0
          def bar; end
        end
      RUBY
      assert_equal(["* **Since:** 1.0.0"], holder.trailing_annotation_lines(holder.object))
    end

    it "renders @version" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @version 1.2.0
          def bar; end
        end
      RUBY
      assert_equal(["* **Version:** 1.2.0"], holder.trailing_annotation_lines(holder.object))
    end

    it "comma-joins multiple @author tags" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @author Ada Lovelace
          # @author Alan Turing
          def bar; end
        end
      RUBY
      assert_equal(["* **Author:** Ada Lovelace, Alan Turing"], holder.trailing_annotation_lines(holder.object))
    end

    it "renders every tag in Todo/Since/Version/Author order regardless of source order" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @author Ada Lovelace
          # @version 1.2.0
          # @since 1.0.0
          # @todo Support more cases.
          def bar; end
        end
      RUBY
      assert_equal(
        [
          "* **Todo:** Support more cases.",
          "* **Since:** 1.0.0",
          "* **Version:** 1.2.0",
          "* **Author:** Ada Lovelace",
        ],
        holder.trailing_annotation_lines(holder.object)
      )
    end
  end

  describe "#annotation_lines_short" do
    it "is empty for an untagged object" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          def bar; end
        end
      RUBY
      assert_empty(holder.annotation_lines_short(holder.object))
    end

    it "detects @private as 'private API'" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @private
          def bar; end
        end
      RUBY
      assert_equal(["private API"], holder.annotation_lines_short(holder.object))
    end

    it "detects @api private as 'private API'" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @api private
          def bar; end
        end
      RUBY
      assert_equal(["private API"], holder.annotation_lines_short(holder.object))
    end

    it "renders a subset in private API/deprecated/abstract order, omitting note" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @note Some note.
          # @abstract
          # @deprecated
          # @private
          def bar; end
        end
      RUBY
      assert_equal(["private API", "deprecated", "abstract"], holder.annotation_lines_short(holder.object))
    end
  end
end
