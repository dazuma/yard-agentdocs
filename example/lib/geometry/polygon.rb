# frozen_string_literal: true

module Geometry
  ##
  # A polygon: a shape with a fixed number of straight sides.
  #
  class Polygon < Shape
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
  end
end
