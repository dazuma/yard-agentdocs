# frozen_string_literal: true

require "helper"

describe ::YARD::AgentDocs::ExampleTags do
  let(:holder) { agentdocs_holder(::YARD::AgentDocs::ExampleTags) }

  # Parses +source+ (a class body) into a fresh registry and returns the
  # object at +path+.
  def object_at(source, path)
    agentdocs_holder(source: source, at: path).object
  end

  describe "#examples_block" do
    it "is nil when there is no @example tag" do
      object = object_at(<<~RUBY, "Foo#bar")
        class Foo
          def bar; end
        end
      RUBY
      assert_nil(holder.examples_block(object))
    end

    it "renders a bare ```ruby fence for an untitled example, under a single header" do
      object = object_at(<<~RUBY, "Foo#bar")
        class Foo
          # @example
          #   Foo.new.bar
          def bar; end
        end
      RUBY
      assert_equal("**Examples:**\n\n```ruby\nFoo.new.bar\n```", holder.examples_block(object))
    end

    it "gives a titled example an italicized title line above its fence" do
      object = object_at(<<~RUBY, "Foo#bar")
        class Foo
          # @example Basic usage
          #   Foo.new.bar
          def bar; end
        end
      RUBY
      assert_equal(
        "**Examples:**\n\n*Basic usage*\n\n```ruby\nFoo.new.bar\n```",
        holder.examples_block(object)
      )
    end

    it "joins multiple examples with a blank line under one header" do
      object = object_at(<<~RUBY, "Foo#bar")
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
        holder.examples_block(object)
      )
    end
  end
end
