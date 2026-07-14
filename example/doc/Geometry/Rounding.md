# module Geometry::Rounding

**Defined in:** `example/lib/geometry/rounding.rb`

Rounding helpers.

Exercises the `module_function` pattern: each method becomes a public
singleton method (`Geometry::Rounding.to_precision(...)`) and, unlike
`extend self` (see `Angles`), a *private* instance method — so mixing
this module in elsewhere would not expose `#to_precision` publicly.

## Member Summary

**Class Methods**

- `.to_precision` — Rounds a value to the given number of decimal places.

## Class Methods

### .to_precision

```ruby
Rounding.to_precision(value, precision) → Float
```

Rounds a value to the given number of decimal places.

**Params:**

- `value` (`Float`) — the value to round
- `precision` (`Integer`) — the number of decimal places

**Returns:**

- `Float` — the rounded value

**Defined in:** `example/lib/geometry/rounding.rb:22`
