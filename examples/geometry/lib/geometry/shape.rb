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
  # @abstract Never instantiated directly; subclass and override `#label`
  #   (see `Polygon`/`Triangle`).
  #
  class Shape
    include Taggable

    ##
    # A short label identifying the kind of shape.
    #
    # @abstract Overridden by every concrete subclass — `Polygon#label`
    #   returns `"polygon"`, and `Triangle` inherits that override.
    # @return [String] the shape's label
    #
    def label
      "shape"
    end

    ##
    # The shape's area.
    #
    # @abstract Every concrete subclass must implement this; unlike
    #   `#label`, no subclass in this example actually overrides it —
    #   this method exists purely to exercise the no-real-implementation
    #   case.
    # @return [Float] the area
    # @raise [NotImplementedError] always, since this base
    #   implementation is never meant to run
    #
    def area
      raise NotImplementedError, "#{self.class} must implement #area"
    end
  end
end
