# frozen_string_literal: true

module Geometry
  ##
  # Mixed into shape classes to add a short bracketed tag string, derived
  # from whatever `#label` the including class defines.
  #
  # Exercises a plain `include` of a module defining instance methods: the
  # including class's own file shows an `**Includes:**` line pointing back
  # here, rather than duplicating `#tag`'s docs inline.
  #
  module Taggable
    ##
    # A short tag for the shape, derived from its label.
    #
    # @return [String] the label wrapped in brackets, e.g. `"[circle]"`
    #
    def tag
      "[#{label}]"
    end
  end
end
