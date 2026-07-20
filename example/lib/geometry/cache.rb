# frozen_string_literal: true

module Geometry
  ##
  # An internal memoization cache used by a few computation-heavy methods
  # elsewhere in this namespace. Kept public — Ruby has no native "private
  # class" concept — but flagged `@private` since it's an implementation
  # detail, not part of the stable public API. Exercises how a
  # `@private`-tagged *class* renders, as opposed to a `@private`-tagged
  # method (`Stopwatch#raw_elapsed_s`).
  #
  # @private
  #
  class Cache
    ##
    # Fetches the cached value for `key`, computing and storing it via
    # `block` if not already present. An ordinary method with no
    # `@private`/`@api` tag of its own, to prove the class-level `@private`
    # tag doesn't cascade to members — `@private` isn't one of YARD's
    # transitive tags, unlike `@since`/`@api`.
    #
    # @param key [Object] the cache key
    # @yieldreturn [Object] the value to store and return if not cached
    # @return [Object] the cached value
    #
    def fetch(key, &block)
      (@entries ||= {}).fetch(key) { @entries[key] = block.call }
    end
  end
end
