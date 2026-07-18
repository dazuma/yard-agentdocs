# frozen_string_literal: true

require "helper"

describe ::YARD::AgentDocs::ExampleTags do
  # Parses +source+ (a class body) into a fresh registry and returns a holder
  # (with {::YARD::AgentDocs::ExampleTags} mixed in) whose +object+ is the
  # object at +path+, in that same still-populated registry.
  def holder_at(source, path)
    agentdocs_holder(::YARD::AgentDocs::ExampleTags, source: source, at: path)
  end

  describe "#examples_block" do
    it "is nil when there is no @example tag" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          def bar; end
        end
      RUBY
      assert_nil(holder.examples_block(holder.object))
    end

    it "renders a bare ```ruby fence for an untitled example, under a single header" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @example
          #   Foo.new.bar
          def bar; end
        end
      RUBY
      assert_equal("**Examples:**\n\n```ruby\nFoo.new.bar\n```", holder.examples_block(holder.object))
    end

    it "gives a titled example an italicized title line above its fence" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @example Basic usage
          #   Foo.new.bar
          def bar; end
        end
      RUBY
      assert_equal(
        "**Examples:**\n\n*Basic usage*\n\n```ruby\nFoo.new.bar\n```",
        holder.examples_block(holder.object)
      )
    end

    it "joins multiple examples with a blank line under one header" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @example Basic usage
          #   Foo.new.bar
          # @example
          #   Foo.new.bar(1)
          def bar; end
        end
      RUBY
      assert_equal(
        "**Examples:**\n\n*Basic usage*\n\n```ruby\nFoo.new.bar\n```\n\n```ruby\nFoo.new.bar(1)\n```",
        holder.examples_block(holder.object)
      )
    end
  end
end
