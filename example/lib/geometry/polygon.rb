# frozen_string_literal: true

module Geometry
  ##
  # A polygon: a shape with a fixed number of straight sides.
  #
  # Also prepends `Loud`, to exercise how `prepend` (as opposed to
  # `include`/`extend`) is presented: `#describe` is defined here, but
  # `Loud`'s own `#describe` actually wins when called, since a `prepend`ed
  # module sits above the class in the method resolution order. YARD's own
  # registry doesn't track which mixin style was used to bring a module in,
  # so `Loud` shows up below under the ordinary `**Includes:**` line,
  # indistinguishable there from a plain `include` — this paragraph is the
  # only place that calls out the actual override behavior.
  #
  class Polygon < Shape
    prepend Loud

    ##
    # Creates a polygon with the given number of sides.
    #
    # @param sides [Integer] the number of sides
    #
    def initialize(sides)
      @sides = sides
    end

    ##
    # The number of sides the polygon has.
    #
    # @return [Integer]
    #
    attr_reader :sides

    ##
    # A short human-readable description of the polygon.
    #
    # @return [String] the description, e.g. `"polygon"`
    #
    def describe
      "polygon"
    end
  end
end
