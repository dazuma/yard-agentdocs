# frozen_string_literal: true

module Geometry
  ##
  # A triangle: a polygon with exactly three sides.
  #
  class Triangle < Polygon
    ##
    # Creates a triangle, with sides fixed to 3.
    #
    def initialize
      super(3)
    end
  end
end
