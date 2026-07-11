# frozen_string_literal: true

module Geometry
  ##
  # Prepended onto a class to upper-case whatever its own `#describe` method
  # returns, without needing to know that method's implementation.
  #
  # Exercises `prepend`: unlike `include`, a `prepend`ed module's method
  # takes precedence over the prepending class's own same-named method — the
  # module sits *above* the class in the method resolution order — so the
  # class's own `#describe` is only reachable via `super`, from inside this
  # module's own override.
  #
  module Loud
    ##
    # Upper-cases the prepending class's own `#describe` result.
    #
    # @return [String] the class's own description, upper-cased
    #
    def describe
      super.upcase
    end
  end
end
