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

    ##
    # Computes the centroid (average position) of one or more points.
    #
    # @param points [Array<Point>] the points to average
    # @return [Point] the centroid of the given points
    #
    def self.centroid(*points)
      Point.new(points.sum(&:x) / points.size.to_f, points.sum(&:y) / points.size.to_f)
    end
  end
end
