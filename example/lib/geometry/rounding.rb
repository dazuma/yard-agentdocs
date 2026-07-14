# frozen_string_literal: true

module Geometry
  ##
  # Rounding helpers.
  #
  # Exercises the `module_function` pattern: each method becomes a public
  # singleton method (`Geometry::Rounding.to_precision(...)`) and, unlike
  # `extend self` (see `Angles`), a *private* instance method — so mixing
  # this module in elsewhere would not expose `#to_precision` publicly.
  #
  module Rounding
    module_function

    ##
    # Rounds a value to the given number of decimal places.
    #
    # @param value [Float] the value to round
    # @param precision [Integer] the number of decimal places
    # @return [Float] the rounded value
    #
    def to_precision(value, precision)
      value.round(precision)
    end
  end
end
