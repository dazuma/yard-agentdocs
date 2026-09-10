# frozen_string_literal: true

module Geometry
  # :nodoc:
  class Scratchpad
    def store(key, value)
      (@entries ||= {})[key] = value
    end

    def fetch(key)
      (@entries ||= {})[key]
    end
  end
end
