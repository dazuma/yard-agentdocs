# frozen_string_literal: true

module Geometry
  ##
  # An immutable 2D displacement vector.
  #
  # @since 2.0.0
  #
  Vector = Data.define(:dx, :dy) do
    ##
    # Computes the magnitude (length) of the vector.
    #
    # @return [Float] the magnitude
    #
    def magnitude
      Math.hypot(dx, dy)
    end
  end
end
