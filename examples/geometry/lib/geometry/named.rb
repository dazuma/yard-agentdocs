# frozen_string_literal: true

module Geometry
  ##
  # Mixed into shape classes via `extend` (not `include`) to add a `.kind`
  # class method, derived from the extending class's own name.
  #
  # Exercises `extend` of a module defining singleton methods: the extending
  # class's own file shows an `**Extends:**` line pointing back here, rather
  # than duplicating `#kind`'s docs inline — same link-out convention as
  # `include`/`**Includes:**` (see `Taggable`).
  #
  module Named
    ##
    # The shape's kind, derived from the extending class's own name.
    #
    # @return [Symbol] the class's short name, downcased — e.g. `:triangle`
    #
    def kind
      name.split("::").last.downcase.to_sym
    end
  end
end
