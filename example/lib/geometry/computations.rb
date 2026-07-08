# frozen_string_literal: true

module Geometry
  ##
  # Utility computations on `Point` values.
  #
  module Computations
    ##
    # Computes the distance between two points.
    #
    # @param a [Point] the first point
    # @param b [Point] the second point
    # @return [Float] the distance between the two points
    # @see Point#distance_to
    #
    def self.distance(a, b)
      a.distance_to(b)
    end
  end
end
