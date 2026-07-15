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

    ##
    # The negation of this vector: same magnitude, opposite direction.
    #
    # @return [Vector] a new vector with both components negated
    #
    def -@
      Vector.new(-dx, -dy)
    end

    ##
    # This vector, unchanged. Included for symmetry with `#-@`; unary `+`
    # is conventionally a no-op in Ruby.
    #
    # @return [Vector] this same vector
    #
    def +@
      self
    end

    ##
    # Whether this vector has the same components as another.
    #
    # Overrides `Data`'s own generated `==` purely to attach documentation
    # to it; the comparison itself (memberwise equality) is unchanged.
    #
    # @param other [Object] the value to compare to
    # @return [Boolean] `true` if `other` is a `Vector` with equal `dx` and `dy`
    #
    def ==(other)
      other.is_a?(Vector) && dx == other.dx && dy == other.dy
    end
  end
end
