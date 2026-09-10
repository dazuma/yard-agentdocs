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
  # Also exercises `{include:...}`/`{render:...}` inline references: both
  # degrade to a plain link, identically to a bare `{Name}` reference —
  # {include:Geometry::Angles} and {render:Geometry::Vector}.
  #
  # Both forms also support a label, rendered as plain text with no
  # backticks: {include:Geometry::Angles the Angles module} and
  # {render:Geometry::Vector the Vector class}.
  #
  # A same-file self-reference degrades the same way a bare self-reference
  # does: {include:Rounding} renders as a plain backtick, and
  # {render:Rounding this very module} renders as plain label text — no
  # link either way.
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
