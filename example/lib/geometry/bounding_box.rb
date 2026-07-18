# frozen_string_literal: true

module Geometry
  ##
  # An axis-aligned bounding box, whose four numeric edges are declared
  # through a small class-level DSL (`.edge`) instead of individual
  # `attr_reader`s.
  #
  # Exercises YARD's attach-mode `@!macro` directive, the workhorse of
  # DSL-heavy and generated codebases: `.edge`'s own doc comment carries no
  # `@return`, since an attach-mode macro doesn't expand at its own
  # definition site, only at each *call site*. Every `edge :name` call below
  # is annotated with nothing more than `@!macro edge` in source; YARD
  # expands that into a synthetic `@!method $1` there, substituting the edge
  # name for `$1`, which in turn defines a real, individually-documented
  # instance method (`#left`, `#top`, etc.) attributed to its own call
  # site's line, not `.edge`'s.
  #
  class BoundingBox
    ##
    # Declares a coercing numeric edge attribute.
    #
    # @!macro [attach] edge
    #   @!method $1
    #     Returns the box's `$1` edge, coerced to a `Float`.
    #     @return [Float] the edge's value
    #
    def self.edge(name)
      define_method(name) { instance_variable_get(:"@#{name}").to_f }
    end

    ##
    # Creates a bounding box from its four edges.
    #
    # @param left [Numeric] the left edge
    # @param top [Numeric] the top edge
    # @param right [Numeric] the right edge
    # @param bottom [Numeric] the bottom edge
    #
    def initialize(left:, top:, right:, bottom:)
      @left = left
      @top = top
      @right = right
      @bottom = bottom
    end

    edge :left
    edge :top
    edge :right
    edge :bottom
  end
end
