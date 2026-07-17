# frozen_string_literal: true

module Geometry
  ##
  # A labeled stop along a route, documented the way YARD supported before
  # `attr_*` gained its own doc-comment convention: `@attr`/`@attr_reader`/
  # `@attr_writer` tags on the class docstring, rather than a comment above
  # each reader/writer method. Both tag forms are themselves `@deprecated`
  # by YARD in favor of the `@!attribute` directive, but real-world gems
  # still carry them.
  #
  # Neither `#label`/`#label=` nor `#order`/`#order=` below has its own doc
  # comment — every word of their documentation comes from these class-level
  # tags, exercising YARD's *other* attribute-registration path (distinct
  # from `attr_reader`/`attr_writer`/`attr_accessor`, see {Rectangle}).
  #
  # @attr_reader label [String] The waypoint's display label.
  # @attr_writer label [String] Reassigns the waypoint's display label.
  # @attr order [Integer] The waypoint's 1-based position in the route.
  #
  class Waypoint
    ##
    # Creates a waypoint with the given label and position.
    #
    # @param label [String] the initial display label
    # @param order [Integer] the initial 1-based position in the route
    #
    def initialize(label, order)
      @label = label
      @order = order
    end

    def label
      @label
    end

    def label=(value)
      @label = value
    end

    def order
      @order
    end

    def order=(value)
      @order = value
    end
  end
end
