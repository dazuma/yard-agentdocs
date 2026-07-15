# module Geometry::Angles

**Extends:** `Angles`
**Defined in:** `example/lib/geometry/angles.rb`

Angle-related helpers.

Exercises the `extend self` pattern: a single method definition that's
simultaneously an instance method (usable if the module is `include`d
elsewhere) and a singleton method (`Geometry::Angles.normalize(...)`,
callable directly on the module itself, no receiver needed).

## Member Summary

**Constants**

- `NAMED_ANGLES` — Degree headings for the four cardinal compass directions, keyed by direction name.

**Instance Methods**

- `#normalize` — Normalizes an angle in degrees to the `[0, 360)` range.

## Constants

### NAMED_ANGLES

**Type:** `Hash{Symbol => Float}`

**Value:**

```ruby
{
  north: 0.0,
  east: 90.0,
  south: 180.0,
  west: 270.0,
}.freeze
```

Degree headings for the four cardinal compass directions, keyed by
direction name.

**Defined in:** `example/lib/geometry/angles.rb:21`

## Instance Methods

### #normalize

```ruby
angles.normalize(degrees) → Float
```

Normalizes an angle in degrees to the `[0, 360)` range.

**Params:**

- `degrees` (`Float`) — the angle to normalize

**Returns:**

- `Float` — the equivalent angle in `[0, 360)`

**Defined in:** `example/lib/geometry/angles.rb:34`
