# Geometry::Shape

**Superclass:** `Object`
**Includes:** [`Taggable`](Taggable.md)
**Defined in:** `example/lib/geometry/shape.rb`

A generic two-dimensional shape.

The base of a three-level example hierarchy (see `Polygon` and
`Triangle`), used to exercise how `yard-agentdocs` presents a
`Superclass:` chain that resolves entirely within the example, rather
than terminating at an unparsed core class like `Object`.

Also includes `Taggable`, to exercise how a directly-`include`d module
is presented (an `**Includes:**` line here, full docs in `Taggable`'s
own file).

## Member Summary

**Instance Methods**

- `#label` — A short label identifying the kind of shape.

## Instance Methods

### #label

```ruby
shape.label() → String
```

A short label identifying the kind of shape.

**Returns:** `String` — the shape's label

**Defined in:** `example/lib/geometry/shape.rb:24`
