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
    # @deprecated Use {Point#distance_to} instead.
    #
    def self.distance(a, b)
      a.distance_to(b)
    end

    ##
    # Computes the centroid (average position) of one or more points.
    #
    # @param points [Array<Point>] the points to average
    # @return [Point] the centroid of the given points
    # @raise [ArgumentError, NoMethodError] if `points` is empty, or if an
    #   element doesn't respond to `#x`/`#y`
    # @see Point the class centroid values are returned as
    # @see Point#distance_to a related method, for measuring distance from a centroid
    # @see https://en.wikipedia.org/wiki/Centroid the Wikipedia definition of a centroid
    #
    def self.centroid(*points)
      raise ArgumentError, "centroid requires at least one point" if points.empty?

      Point.new(average(points.map(&:x)), average(points.map(&:y)))
    end

    ##
    # Yields each of the given points in turn.
    #
    # @param points [Array<Point>] the points to iterate over
    # @yieldparam point [Point] each point, in the order given
    # @return [Integer] the number of points yielded
    #
    def self.each_point(*points)
      points.each { |p| yield p }
      points.size
    end

    ##
    # Groups the given points by which quadrant of the coordinate plane
    # they fall in, relative to the origin. Exercises a nested compound
    # type: an `Array` of `Point`, grouped into a `Hash` keyed by
    # quadrant name.
    #
    # @param points [Array<Point>] the points to group
    # @return [Hash{Symbol => Array<Point>}] the points, bucketed by
    #   quadrant name (`:northeast`, `:northwest`, `:southeast`,
    #   `:southwest`)
    #
    def self.group_by_quadrant(points)
      points.group_by do |point|
        if point.y >= 0
          point.x >= 0 ? :northeast : :northwest
        else
          point.x >= 0 ? :southeast : :southwest
        end
      end
    end

    ##
    # Averages an array of numbers. Shared by {.centroid}'s x/y averaging,
    # kept out of the public API since it isn't specific to points.
    #
    # @param values [Array<Numeric>] the numbers to average
    # @return [Float] the arithmetic mean of `values`
    #
    def self.average(values)
      values.sum / values.size.to_f
    end
    private_class_method :average
  end
end
