# frozen_string_literal: true

module Geometry
  ##
  # A generic two-dimensional shape.
  #
  # The base of a three-level example hierarchy (see `Polygon` and
  # `Triangle`), used to exercise how `yard-agentdocs` presents a
  # `Superclass:` chain that resolves entirely within the example, rather
  # than terminating at an unparsed core class like `Object`.
  #
  # Also includes `Taggable`, to exercise how a directly-`include`d module
  # is presented (an `**Includes:**` line here, full docs in `Taggable`'s
  # own file).
  #
  class Shape
    include Taggable

    ##
    # A short label identifying the kind of shape.
    #
    # @return [String] the shape's label
    #
    def label
      "shape"
    end
  end
end
