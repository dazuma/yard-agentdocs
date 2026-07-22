# frozen_string_literal: true

require "helper"

describe ::YARD::AgentDocs::NodocFilter do
  # Parses +source+ into a fresh registry and returns a holder (with
  # {::YARD::AgentDocs::NodocFilter} mixed in) whose +object+ is the object
  # at +path+, in that same still-populated registry.
  def holder_at(source, path)
    agentdocs_holder(::YARD::AgentDocs::NodocFilter, source: source, at: path)
  end

  describe "#bare_nodoc?" do
    it "is true for a method documented with nothing but :nodoc:" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # :nodoc:
          def bar; end
        end
      RUBY
      assert(holder.bare_nodoc?(holder.object))
    end

    it "is true for a class documented with nothing but :nodoc:" do
      holder = holder_at(<<~RUBY, "Foo")
        # :nodoc:
        class Foo
        end
      RUBY
      assert(holder.bare_nodoc?(holder.object))
    end

    it "is true for a constant documented with nothing but :nodoc:" do
      holder = holder_at(<<~RUBY, "Foo::BAR")
        class Foo
          # :nodoc:
          BAR = 1
        end
      RUBY
      assert(holder.bare_nodoc?(holder.object))
    end

    it "is false for an untagged object" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          def bar; end
        end
      RUBY
      refute(holder.bare_nodoc?(holder.object))
    end

    it "is false when :nodoc: appears alongside real prose" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # Really an internal helper. :nodoc:
          def bar; end
        end
      RUBY
      refute(holder.bare_nodoc?(holder.object))
    end

    it "is false for a bare :stopdoc:/:startdoc: docstring" do
      holder = holder_at(<<~RUBY, "Foo#bar")
        class Foo
          # :stopdoc:
          def bar; end
        end
      RUBY
      refute(holder.bare_nodoc?(holder.object))
    end
  end
end
