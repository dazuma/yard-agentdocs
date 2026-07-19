# frozen_string_literal: true

module Geometry
  module ThreeD
    ##
    # A point in three-dimensional space, analogous to {Geometry::Point}.
    #
    class Point
      ##
      # Creates a point from its coordinates.
      #
      # @param x [Numeric] the x-coordinate
      # @param y [Numeric] the y-coordinate
      # @param z [Numeric] the z-coordinate
      #
      def initialize(x, y, z)
        @x = x
        @y = y
        @z = z
      end

      ##
      # Computes the distance from the origin.
      #
      # @return [Float] the distance
      #
      def magnitude
        Math.sqrt((@x**2) + (@y**2) + (@z**2))
      end
    end
  end
end
