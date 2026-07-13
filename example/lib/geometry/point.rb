# frozen_string_literal: true

module Geometry
  ##
  # A point in two-dimensional space.
  #
  # Doesn't mix in {Comparable}, so points aren't directly sortable or
  # comparable with `<=>`.
  #
  class Point
    ##
    # The number of coordinates a point has.
    #
    # @return [Integer]
    #
    DIMENSIONS = 2

    ##
    # The x-coordinate.
    #
    # @return [Numeric]
    #
    attr_reader :x

    ##
    # The y-coordinate.
    #
    # @return [Numeric]
    #
    attr_reader :y

    ##
    # Creates a point from its coordinates.
    #
    # @param x [Numeric] the x-coordinate
    # @param y [Numeric] the y-coordinate
    #
    def initialize(x, y)
      @x = x
      @y = y
    end

    ##
    # The point at the origin, `(0, 0)`.
    #
    # @return [Point]
    #
    ORIGIN = new(0, 0)

    ##
    # Parses a point from a string formatted as `"x,y"`.
    #
    # @param str [String] a string such as `"3,4"`
    # @return [Point] the parsed point
    #
    def self.parse(str)
      x, y = str.split(",").map(&:to_i)
      new(x, y)
    end

    ##
    # Creates a point from polar coordinates.
    #
    # @param radius [Numeric] the distance from the origin
    # @param angle [Numeric] the angle from the positive x-axis, in radians
    # @return [Point] the point in Cartesian coordinates
    #
    def self.from_polar(radius:, angle:)
      new(radius * Math.cos(angle), radius * Math.sin(angle))
    end

    ##
    # Adds this point to another, component-wise.
    #
    # @param other [Point] the point to add
    # @return [Point] a new point whose coordinates are the sum of the two
    #
    def +(other)
      Point.new(x + other.x, y + other.y)
    end

    ##
    # Computes the Euclidean distance to another point.
    #
    # @param other [Point] the point to measure distance to
    # @return [Float] the distance between the two points
    #
    def distance_to(other)
      Math.hypot(x - other.x, y - other.y)
    end

    ##
    # Rounds this point's coordinates to the given decimal precision.
    #
    # @param precision [Integer] the number of decimal places to round to
    # @return [Point] a new point with rounded coordinates
    #
    def round(precision: 0)
      Point.new(x.round(precision), y.round(precision))
    end

    ##
    # Shifts this point by the given coordinate deltas. Any coordinate not
    # given defaults to no change.
    #
    # @param deltas [Hash{Symbol => Numeric}] `:x` and/or `:y` offsets to add
    # @return [Point] a new point shifted by the given deltas
    #
    def translate(**deltas)
      Point.new(x + deltas.fetch(:x, 0), y + deltas.fetch(:y, 0))
    end
  end
end
