# frozen_string_literal: true

require "helper"

describe "version constant" do
  it "is a dotted major.minor.patch version string" do
    assert_match(/\A\d+\.\d+\.\d+\z/, ::YARD::AgentDocs::VERSION)
  end
end
