# frozen_string_literal: true

module Geometry
  ##
  # An internal memoization cache used by a few computation-heavy methods
  # elsewhere in this namespace. Kept public — Ruby has no native "private
  # class" concept — but flagged `@private` since it's an implementation
  # detail, not part of the stable public API. Exercises how a
  # `@private`-tagged *class* renders, as opposed to a `@private`-tagged
  # method ({Stopwatch#raw_elapsed_s}) — also, since that reference is two
  # full namespace hops away from its target (`Geometry::Cache` up to
  # `Geometry` up to the top level), exercises the lexical cross-reference
  # resolution cap workaround.
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

    ##
    # Sets the memoized value under `key`, either directly or lazily.
    #
    # Exercises per-overload `@yieldreturn`, `@raise`, and `@see` — real
    # precedent for `@yieldreturn` from `functions_framework`'s
    # `Function::Callable#set_global`, which has this exact "value form" /
    # "block form" shape and declares `@yieldreturn` only on the block
    # form; `@raise`/`@see` have no such real-world precedent yet but are
    # included on the same footing by deliberate choice (see DESIGN.md's
    # per-overload checklist item).
    #
    # @overload set(key, value)
    #   Sets `key` directly to `value`.
    #
    #   @param key [Object] the cache key
    #   @param value [Object] the value to store
    #   @raise [ArgumentError] if `value` is `nil` (indistinguishable from not passing a value at all)
    #   @return [self]
    #
    # @overload set(key, &block)
    #   Defers computing the value until `key` is first read, by calling
    #   the given block at most once; its result is reused for subsequent
    #   reads.
    #
    #   @param key [Object] the cache key
    #   @yieldreturn [Object] the value to compute and store, lazily
    #   @see #fetch the method that triggers the block
    #   @return [self]
    #
    def set(key, value = nil, &block)
      @entries ||= {}
      if block
        @entries[key] = block
      else
        raise ::ArgumentError, "value must not be nil" if value.nil?

        @entries[key] = value
      end
      self
    end
  end
end
