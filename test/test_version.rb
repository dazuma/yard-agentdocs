# frozen_string_literal: true

require "helper"

describe "version constant" do
  it "is set" do
    assert(defined?(::YARD::Agents::VERSION))
  end
end
