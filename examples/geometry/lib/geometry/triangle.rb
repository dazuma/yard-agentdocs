# frozen_string_literal: true

module Geometry
  ##
  # A triangle: a polygon with exactly three sides.
  #
  # Also extends `Named`, to exercise how `extend` of a module (as opposed to
  # `include`) is presented: an `**Extends:**` line here, full docs in
  # `Named`'s own file.
  #
  # See {Geometry::Polygon the base Polygon class} for the shared
  # sides/description behavior, and {Named} for how the naming itself is
  # derived.
  #
  class Triangle < Polygon
    extend Named

    ##
    # Creates a triangle, with sides fixed to 3.
    #
    def initialize
      super(3)
    end
  end
end
