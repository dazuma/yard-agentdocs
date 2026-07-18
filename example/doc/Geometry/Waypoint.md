# class Geometry::Waypoint

- **Superclass:** `Object`
- **Defined in:** `example/lib/geometry/waypoint.rb`

A labeled stop along a route, documented the way YARD supported before
`attr_*` gained its own doc-comment convention: `@attr`/`@attr_reader`/
`@attr_writer` tags on the class docstring, rather than a comment above
each reader/writer method. Both tag forms are themselves `@deprecated`
by YARD in favor of the `@!attribute` directive, but real-world gems
still carry them.

Neither `#label`/`#label=` nor `#order`/`#order=` below has its own doc
comment — every word of their documentation comes from these class-level
tags, exercising YARD's *other* attribute-registration path (distinct
from `attr_reader`/`attr_writer`/`attr_accessor`, see [`Rectangle`](Rectangle.md)).

## Member Summary

**Instance Attributes**

- `#label` — The waypoint's display label.
- `#order` — The waypoint's 1-based position in the route.

**Class Methods**

- `.new` — Creates a waypoint with the given label and position.

## Instance Attributes

### #label

- **Type:** `String`

The waypoint's display label.

* **Defined in:** `example/lib/geometry/waypoint.rb:21`

### #order

- **Type:** `Integer`

The waypoint's 1-based position in the route.

* **Defined in:** `example/lib/geometry/waypoint.rb:21`

## Class Methods

### .new

*(Ruby's default constructor; documents `#initialize`.)*

```ruby
Waypoint.new(label, order) → Waypoint
```

Creates a waypoint with the given label and position.

**Params:**

- `label` (`String`) — the initial display label
- `order` (`Integer`) — the initial 1-based position in the route

* **Defined in:** `example/lib/geometry/waypoint.rb:28`
