# frozen_string_literal: true

require "helper"

describe ::YARD::AgentDocs::VisibilityInfo do
  # Parses +source+ (a class body) into a fresh registry and returns a holder
  # (with {::YARD::AgentDocs::VisibilityInfo} mixed in) whose +object+ is the
  # object at +path+, in that same still-populated registry.
  def holder_at(source, path)
    agentdocs_holder(::YARD::AgentDocs::VisibilityInfo, source: source, at: path)
  end

  describe "#private_api?" do
    it "is true for an object tagged @private" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @private
          def bar; end
        end
      RUBY
      assert(holder.private_api?(holder.object))
    end

    it "is true for an object tagged @api private" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @api private
          def bar; end
        end
      RUBY
      assert(holder.private_api?(holder.object))
    end

    it "is false for an object tagged @api public" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @api public
          def bar; end
        end
      RUBY
      refute(holder.private_api?(holder.object))
    end

    it "is false for an untagged object" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          def bar; end
        end
      RUBY
      refute(holder.private_api?(holder.object))
    end
  end

  describe "#private_api_annotation" do
    it "is 'Private API.' for a private-API object" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @private
          def bar; end
        end
      RUBY
      assert_equal("Private API.", holder.private_api_annotation(holder.object))
    end

    it "is nil for an untagged object" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          def bar; end
        end
      RUBY
      assert_nil(holder.private_api_annotation(holder.object))
    end
  end

  describe "#private_api_annotation_short" do
    it "is 'private API' for a private-API object" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # @private
          def bar; end
        end
      RUBY
      assert_equal("private API", holder.private_api_annotation_short(holder.object))
    end

    it "is nil for an untagged object" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          def bar; end
        end
      RUBY
      assert_nil(holder.private_api_annotation_short(holder.object))
    end
  end
end
