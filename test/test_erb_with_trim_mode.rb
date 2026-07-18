# frozen_string_literal: true

require "helper"

describe ::YARD::AgentDocs::ErbWithTrimMode do
  let(:holder) { agentdocs_holder(::YARD::AgentDocs::ErbWithTrimMode) }

  describe "#erb_with" do
    it "returns an ERB instance" do
      erb = holder.erb_with("hello")
      assert_kind_of(::ERB, erb)
    end

    it "honors <%- -%> trimming, leaving no stray blank lines from a false branch" do
      template = <<~ERB
        before
        <%- if false -%>
        shown only if true
        <%- end -%>
        after
      ERB
      erb = holder.erb_with(template)
      assert_equal("before\nafter\n", erb.result(binding))
    end

    it "renders a true branch's content with no extra blank lines around it" do
      template = <<~ERB
        before
        <%- if true -%>
        shown
        <%- end -%>
        after
      ERB
      erb = holder.erb_with(template)
      assert_equal("before\nshown\nafter\n", erb.result(binding))
    end

    it "sets the filename when given, for backtraces" do
      erb = holder.erb_with("hello", "my_template.erb")
      assert_equal("my_template.erb", erb.filename)
    end

    it "leaves the filename nil when not given" do
      erb = holder.erb_with("hello")
      assert_nil(erb.filename)
    end
  end
end
