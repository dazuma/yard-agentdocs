# frozen_string_literal: true

module Geometry
  class Rectangle
    ##
    # Computes the perimeter of the rectangle.
    #
    # @return [Float] the perimeter
    #
    def perimeter
      2 * (@width + @height)
    end
  end
end
