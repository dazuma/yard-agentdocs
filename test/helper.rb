# frozen_string_literal: true

require "minitest/autorun"
require "minitest/focus"
require "minitest/rg"

require "yard-agentdocs"

module AgentdocsTestHelper
  ##
  # Builds a small "template-like" holder object for exercising one or more
  # `YARD::AgentDocs` mixins in isolation, mirroring the `object`/`options`
  # surface `YARD::Templates::Template` normally provides.
  #
  # Always starts from a freshly-cleared `YARD::Registry`, matching how each
  # test previously started (whether or not it parsed anything of its own),
  # so tests never see leftover state from another example.
  #
  # @param mixins [Array<Module>] modules to include into the holder class
  # @param source [String, nil] a class/module body to parse into the fresh
  #   registry before building the holder (typically used together with
  #   +at:+)
  # @param at [String, nil] the registry path to set as the holder's
  #   +object+, mirroring how a template sees the object currently being
  #   rendered
  # @param markup [Symbol, nil] when given, the holder's +options+ responds
  #   to +#markup+ with this value, standing in for
  #   +YARD::Templates::TemplateOptions+
  # @return [Object] a holder instance with +mixins+ included and
  #   +object+/+options+ set as requested
  #
  def agentdocs_holder(*mixins, source: nil, at: nil, markup: nil)
    ::YARD::Registry.clear
    ::YARD.parse_string(source) if source

    holder_class = ::Class.new do
      mixins.each { |mixin| include mixin }
      attr_accessor :object, :options
    end

    holder_class.new.tap do |holder|
      holder.object = ::YARD::Registry.at(at) if at
      holder.options = ::Struct.new(:markup).new(markup) if markup
    end
  end
end

Minitest::Spec.include(AgentdocsTestHelper)
