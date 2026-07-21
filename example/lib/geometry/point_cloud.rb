# frozen_string_literal: true

module Geometry
  ##
  # A fixed collection of points.
  #
  # Exercises YARD's `@!attribute` directive: `#size` isn't declared via
  # `attr_reader` or any of the `@attr`/`@attr_reader`/`@attr_writer` tags
  # ({Waypoint}'s manual-pair fixture) — it's a bare `define_method` call
  # with no source declaration of its own for a docstring to attach to, so
  # `@!attribute [r]` supplies one directly. As with `@!method`/`@!macro`
  # (see {BoundingBox}, {CompassRose}), descriptive text has to be indented
  # *under* the directive line to become the attribute's own docstring — a
  # sibling-indented paragraph above the directive attaches to nothing.
  #
  # `#centroid` exercises a distinct case: its `@!attribute` directive has
  # no indented free-text paragraph of its own at all — the only
  # description anywhere is the text inside its `@return` tag, so the
  # attribute's own docstring is genuinely empty.
  #
  # See {file:example/docs/point_cloud.md} for a worked example.
  #
  class PointCloud
    ##
    # @!attribute [r] size
    #   The number of points in the cloud.
    #   @return [Integer] the number of points in the cloud
    #
    define_method(:size) { @points.size }

    ##
    # @!attribute [r] centroid
    #   @return [Point] the average position of all points in the cloud
    #
    define_method(:centroid) do
      Point.new(@points.sum(&:x) / @points.size.to_f, @points.sum(&:y) / @points.size.to_f)
    end

    ##
    # Creates a point cloud from the given points.
    #
    # @param points [Array<Point>] the points to collect
    #
    def initialize(points)
      @points = points
    end
  end
end
