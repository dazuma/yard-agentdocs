# class Geometry::Cache

- **Superclass:** `Object`
- **Defined in:** `example/lib/geometry/cache.rb`

* **Private API.**

An internal memoization cache used by a few computation-heavy methods
elsewhere in this namespace. Kept public — Ruby has no native "private
class" concept — but flagged `@private` since it's an implementation
detail, not part of the stable public API. Exercises how a
`@private`-tagged *class* renders, as opposed to a `@private`-tagged
method (`Stopwatch#raw_elapsed_s`).

## Member Summary

**Instance Methods**

- `#fetch` — Fetches the cached value for `key`, computing and storing it via `block` if not already present.

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

* **Defined in:** `example/lib/geometry/cache.rb:26`
