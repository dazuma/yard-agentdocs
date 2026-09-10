# frozen_string_literal: true

module Geometry
  ##
  # Compass-bearing lookups, one instance method per cardinal direction.
  #
  # Reuses the direction names from {Angles::NAMED_ANGLES} rather than a
  # fresh literal, and exercises YARD's `@!method` directive without an
  # accompanying `@!macro` — the idiomatic way to document methods defined
  # by looping over runtime data, where there's no per-iteration call site
  # for a macro to expand at (contrast {BoundingBox}, where each generated
  # method comes from its own `edge :name` call). Stacking one `@!method`
  # directive per generated method above the single `each` call that
  # defines them all — YARD's own documented "Attaching multiple methods to
  # the same source" pattern — is the fix: all four methods below end up
  # individually documented, but share one `**Defined in:**` line, since
  # they're all attributed to that same call site.
  #
  class CompassRose
    # @!method north
    #   Returns north's bearing, in degrees.
    #   @return [Float] the bearing
    # @!method east
    #   Returns east's bearing, in degrees.
    #   @return [Float] the bearing
    # @!method south
    #   Returns south's bearing, in degrees.
    #   @return [Float] the bearing
    # @!method west
    #   Returns west's bearing, in degrees.
    #   @return [Float] the bearing
    Angles::NAMED_ANGLES.each_key do |direction|
      define_method(direction) { Angles::NAMED_ANGLES[direction] }
    end
  end
end
