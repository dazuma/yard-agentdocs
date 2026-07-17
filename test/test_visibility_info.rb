# frozen_string_literal: true

require "helper"

describe ::YARD::AgentDocs::VisibilityInfo do
  let(:holder) { agentdocs_holder(::YARD::AgentDocs::VisibilityInfo) }

  # Parses +source+ (a class body) into a fresh registry and returns the
  # object at +path+.
  def object_at(source, path)
    agentdocs_holder(source: source, at: path).object
  end

  describe "#private_api?" do
    it "is true for an object tagged @private" do
      object = object_at(<<~RUBY, "Foo#bar")
        class Foo
          # @private
          def bar; end
        end
      RUBY
      assert(holder.private_api?(object))
    end

    it "is true for an object tagged @api private" do
      object = object_at(<<~RUBY, "Foo#bar")
        class Foo
          # @api private
          def bar; end
        end
      RUBY
      assert(holder.private_api?(object))
    end

    it "is false for an object tagged @api public" do
      object = object_at(<<~RUBY, "Foo#bar")
        class Foo
          # @api public
          def bar; end
        end
      RUBY
      refute(holder.private_api?(object))
    end

    it "is false for an untagged object" do
      object = object_at(<<~RUBY, "Foo#bar")
        class Foo
          def bar; end
        end
      RUBY
      refute(holder.private_api?(object))
    end
  end

  describe "#private_api_annotation" do
    it "is 'Private API.' for a private-API object" do
      object = object_at(<<~RUBY, "Foo#bar")
        class Foo
          # @private
          def bar; end
        end
      RUBY
      assert_equal("Private API.", holder.private_api_annotation(object))
    end

    it "is nil for an untagged object" do
      object = object_at(<<~RUBY, "Foo#bar")
        class Foo
          def bar; end
        end
      RUBY
      assert_nil(holder.private_api_annotation(object))
    end
  end

  describe "#private_api_annotation_short" do
    it "is 'private API' for a private-API object" do
      object = object_at(<<~RUBY, "Foo#bar")
        class Foo
          # @private
          def bar; end
        end
      RUBY
      assert_equal("private API", holder.private_api_annotation_short(object))
    end

    it "is nil for an untagged object" do
      object = object_at(<<~RUBY, "Foo#bar")
        class Foo
          def bar; end
        end
      RUBY
      assert_nil(holder.private_api_annotation_short(object))
    end
  end
end
