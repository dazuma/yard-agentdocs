# frozen_string_literal: true

module Geometry
  ##
  # An ordered sequence of points.
  #
  # Includes the stdlib `Enumerable` module — defined outside this
  # example's own source — to exercise how a mixin whose docs live
  # entirely outside the parsed source renders: `Enumerable` methods like
  # `#map`/`#select`/`#first` are all available too, none of them
  # documented on this page.
  #
  class Path
    include Enumerable

    ##
    # Creates a path visiting the given points in order.
    #
    # @param points [Array<Point>] the points to visit, in order
    #
    def initialize(*points)
      @points = points
    end

    ##
    # Appends a point to the end of the path.
    #
    # @param point [Point] the point to append
    # @return [self] this path, for chaining
    #
    def add(point)
      @points << point
      self
    end

    ##
    # Removes every point from the path.
    #
    # @return [void]
    #
    def clear
      @points.clear
    end

    ##
    # Finds the point in the path closest to the given target.
    #
    # @param target [Point] the point to measure distance from
    # @return [Point, nil] the closest point, or `nil` if the path has no points
    #
    def closest_to(target)
      return nil if @points.empty?

      @points.min_by { |point| point.distance_to(target) }
    end

    ##
    # Yields each point in the path, in order.
    #
    # @yieldparam point [Point] each point, in the order given
    # @return [Integer] the number of points in the path
    #
    def each
      @points.each { |point| yield point }
      @points.size
    end

    ##
    # Builds the segment connecting the points at `index` and `index + 1`.
    #
    # @param index [Integer] the index of the first point in the segment
    # @return [Segment] the segment between the two consecutive points
    # @return [nil] if `index` is out of range
    #
    def segment_at(index)
      return nil unless (0...(@points.size - 1)).cover?(index)

      Segment.new(@points[index], @points[index + 1])
    end

    ##
    # Replaces each point in the path with the block's result, in place.
    #
    # @yieldparam point [Point] each point, in order
    # @yieldreturn [Point] the replacement for this point
    # @yieldreturn [nil] to leave this point unchanged
    # @return [self] this path, for chaining
    #
    def transform!
      @points.map! { |point| yield(point) || point }
      self
    end
  end
end
