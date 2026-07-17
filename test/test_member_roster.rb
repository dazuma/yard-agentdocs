# frozen_string_literal: true

require "helper"

# {::YARD::AgentDocs::MemberListing} calls `run_verifier`, normally provided
# by `YARD::Templates::Template` to apply `--no-private`/`--no-protected`
# filtering; a plain pass-through stands in for it in test/test_member_roster.rb,
# since none of those tests configure a verifier.
module NoopVerifier
  def run_verifier(list)
    list
  end
end

describe ::YARD::AgentDocs::MemberRoster do
  # Parses +source+ into a fresh registry and returns a holder (with
  # {NoopVerifier}, {::YARD::AgentDocs::MemberRoster},
  # {::YARD::AgentDocs::MemberListing}, {::YARD::AgentDocs::MethodSignature},
  # and {::YARD::AgentDocs::CrossReferencing} mixed in) whose +object+ is
  # +path+.
  def holder_for(source, path)
    agentdocs_holder(
      NoopVerifier,
      ::YARD::AgentDocs::MemberRoster, ::YARD::AgentDocs::MemberListing,
      ::YARD::AgentDocs::MethodSignature, ::YARD::AgentDocs::CrossReferencing,
      source: source, at: path
    )
  end

  describe "#member_roster_lines" do
    it "lists a name the superclass contributes that the subclass doesn't have" do
      holder = holder_for(<<~RUBY, "Sub")
        class Base
          def base_method; end
        end

        class Sub < Base
        end
      RUBY
      assert_equal(
        ["- **Inherited from [`Base`](Base.md):** `#base_method`"],
        holder.member_roster_lines
      )
    end

    it "excludes an own member, including an override, from the roster" do
      holder = holder_for(<<~RUBY, "Sub")
        class Base
          def base_method; end
          def shared_method; end
        end

        class Sub < Base
          def shared_method; end
        end
      RUBY
      assert_equal(
        ["- **Inherited from [`Base`](Base.md):** `#base_method`"],
        holder.member_roster_lines
      )
    end

    it "lists an include'd module's instance methods and constants, but not its own class methods" do
      holder = holder_for(<<~RUBY, "Host")
        module Mixin
          FOO = 1

          def instance_thing; end

          def self.class_thing; end
        end

        class Host
          include Mixin
        end
      RUBY
      assert_equal(
        ["- **Included from [`Mixin`](Mixin.md):** `#instance_thing`, `FOO`"],
        holder.member_roster_lines
      )
    end

    it "lists an extend'ed module's instance methods with a '.' sigil" do
      holder = holder_for(<<~RUBY, "Host")
        module Ext
          def ext_thing; end
        end

        class Host
          extend Ext
        end
      RUBY
      assert_equal(
        ["- **Extended from [`Ext`](Ext.md):** `.ext_thing`"],
        holder.member_roster_lines
      )
    end

    it "skips a self-extended module (extend self)" do
      holder = holder_for(<<~RUBY, "SelfExt")
        module SelfExt
          extend self

          def thing; end
        end
      RUBY
      assert_empty(holder.member_roster_lines)
    end

    it "is empty when everything an include'd module contributes is already shadowed" do
      holder = holder_for(<<~RUBY, "Host")
        module Mixin
          def thing; end
        end

        class Host
          include Mixin

          def thing; end
        end
      RUBY
      assert_empty(holder.member_roster_lines)
    end
  end
end
