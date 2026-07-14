# frozen_string_literal: true

module Geometry
  ##
  # A circle, defined by its radius.
  #
  # @deprecated Struct-based value objects like this one are being phased
  #   out in favor of Ruby's newer `Data.define`. Kept here only to keep
  #   exercising the `Struct.new` case.
  # @example Computing a circle's area
  #   Circle.new(2).area.round(2)
  #   #=> 12.57
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
