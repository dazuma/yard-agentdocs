# frozen_string_literal: true

module Geometry
  ##
  # Angle-related helpers.
  #
  # Exercises the `extend self` pattern: a single method definition that's
  # simultaneously an instance method (usable if the module is `include`d
  # elsewhere) and a singleton method (`Geometry::Angles.normalize(...)`,
  # callable directly on the module itself, no receiver needed).
  #
  module Angles
    extend self

    ##
    # Normalizes an angle in degrees to the `[0, 360)` range.
    #
    # @param degrees [Float] the angle to normalize
    # @return [Float] the equivalent angle in `[0, 360)`
    #
    def normalize(degrees)
      degrees % 360.0
    end
  end
end
