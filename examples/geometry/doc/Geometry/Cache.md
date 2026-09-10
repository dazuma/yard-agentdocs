---
type: Ruby Class
title: Geometry::Cache
description: "An internal memoization cache used by a few computation-heavy methods elsewhere in this namespace."
---

# class Geometry::Cache

- **Superclass:** `Object`
- **Defined in:** `examples/geometry/lib/geometry/cache.rb`

* **Private API.**

An internal memoization cache used by a few computation-heavy methods
elsewhere in this namespace. Kept public — Ruby has no native "private
class" concept — but flagged `@private` since it's an implementation
detail, not part of the stable public API. Exercises how a
`@private`-tagged *class* renders, as opposed to a `@private`-tagged
method ([`Stopwatch#raw_elapsed_s`](../Stopwatch.md)) — also, since that reference is two
full namespace hops away from its target (`Geometry::Cache` up to
`Geometry` up to the top level), exercises the lexical cross-reference
resolution cap workaround.

## Member Summary

**Instance Methods**

- `#fetch` — Fetches the cached value for `key`, computing and storing it via `block` if not already present.
- `#set` — Sets the memoized value under `key`, either directly or lazily.

## Instance Methods

### #fetch

```ruby
cache.fetch(key, &block) → Object
```

Fetches the cached value for `key`, computing and storing it via
`block` if not already present. An ordinary method with no
`@private`/`@api` tag of its own, to prove the class-level `@private`
tag doesn't cascade to members — `@private` isn't one of YARD's
transitive tags, unlike `@since`/`@api`.

**Params:**

- `key` (`Object`) — the cache key

**Yield Returns:**

- `Object` — the value to store and return if not cached

**Returns:**

- `Object` — the cached value

* **Defined in:** `examples/geometry/lib/geometry/cache.rb:29`

### #set

```ruby
cache.set(key, value) → self
cache.set(key, &block) → self
```

Sets the memoized value under `key`, either directly or lazily.

Exercises per-overload `@yieldreturn`, `@raise`, and `@see` — real
precedent for `@yieldreturn` from `functions_framework`'s
`Function::Callable#set_global`, which has this exact "value form" /
"block form" shape and declares `@yieldreturn` only on the block
form; `@raise`/`@see` have no such real-world precedent yet but are
included on the same footing by deliberate choice (see DESIGN.md's
per-overload checklist item).

**`cache.set(key, value) → self`**

Sets `key` directly to `value`.

**Params:**

- `key` (`Object`) — the cache key
- `value` (`Object`) — the value to store

**Returns:**

- `self`

**Raises:**

- `ArgumentError` — if `value` is `nil` (indistinguishable from not passing a value at all)

**`cache.set(key, &block) → self`**

Defers computing the value until `key` is first read, by calling
the given block at most once; its result is reused for subsequent
reads.

**Params:**

- `key` (`Object`) — the cache key

**Yield Returns:**

- `Object` — the value to compute and store, lazily

**Returns:**

- `self`

**See also:**

- `#fetch` — the method that triggers the block

* **Defined in:** `examples/geometry/lib/geometry/cache.rb:62`
