# class Geometry::Triangle

**Superclass:** [`Polygon`](Polygon.md)
**Extends:** [`Named`](Named.md)
**Defined in:** `example/lib/geometry/triangle.rb`

A triangle: a polygon with exactly three sides.

Also extends `Named`, to exercise how `extend` of a module (as opposed to
`include`) is presented: an `**Extends:**` line here, full docs in
`Named`'s own file.

## Member Summary

**Class Methods**

- `.new` — Creates a triangle, with sides fixed to 3.

## Class Methods

### .new

*(Ruby's default constructor; documents `#initialize`.)*

```ruby
Triangle.new() → Triangle
```

Creates a triangle, with sides fixed to 3.

**Defined in:** `example/lib/geometry/triangle.rb:17`
