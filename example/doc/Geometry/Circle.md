# class Geometry::Circle

**Superclass:** `Struct`
**Defined in:** `example/lib/geometry/circle.rb`

**Deprecated.** Struct-based value objects like this one are being phased
out in favor of Ruby's newer `Data.define`. Kept here only to keep
exercising the `Struct.new` case.

A circle, defined by its radius.

## Member Summary

**Attributes**

- `#radius` — Returns the value of attribute radius.

**Instance Methods**

- `#area` — Computes the area of the circle.

## Attributes

### #radius

**Type:** `Object`

Returns the value of attribute radius

**Defined in:** `example/lib/geometry/circle.rb:11`

## Instance Methods

### #area

```ruby
circle.area() → Float
```

Computes the area of the circle.

**Returns:** `Float` — the area

**Defined in:** `example/lib/geometry/circle.rb:17`
