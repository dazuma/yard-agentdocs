# frozen_string_literal: true

module Geometry
  ##
  # An ordered sequence of points.
  #
  # Includes the stdlib `Enumerable` module — defined outside this
  # example's own source — to exercise how a mixin whose docs live
  # entirely outside the parsed source renders: `#each` is the only method
  # actually defined here, but `Enumerable` methods like `#map`/`#select`/
  # `#first` are all available too, none of them documented on this page.
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
    # Yields each point in the path, in order.
    #
    # @yieldparam point [Point] each point, in the order given
    # @return [Integer] the number of points in the path
    #
    def each
      @points.each { |point| yield point }
      @points.size
    end
  end
end
