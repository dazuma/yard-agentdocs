# frozen_string_literal: true

module Geometry
  ##
  # A circle, defined by its radius.
  #
  Circle = Struct.new(:radius) do
    ##
    # Computes the area of the circle.
    #
    # @return [Float] the area
    #
    def area
      Math::PI * (radius**2)
    end
  end
end
