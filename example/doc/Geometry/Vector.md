# class Geometry::Vector

**Superclass:** `Data`
**Since:** 2.0.0
**Defined in:** `example/lib/geometry/vector.rb`

An immutable 2D displacement vector.

## Member Summary

**Attributes**

- `#dx` (read-only) — Returns the value of attribute dx.
- `#dy` (read-only) — Returns the value of attribute dy.

**Instance Methods**

- `#+@` — This vector, unchanged.
- `#-@` — The negation of this vector: same magnitude, opposite direction.
- `#==` — Whether this vector has the same components as another.
- `#magnitude` — Computes the magnitude (length) of the vector.

## Attributes

### #dx

**Type:** `Object`
**Read-only.**

Returns the value of attribute dx

**Defined in:** `example/lib/geometry/vector.rb:9`

### #dy

**Type:** `Object`
**Read-only.**

Returns the value of attribute dy

**Defined in:** `example/lib/geometry/vector.rb:9`

## Instance Methods

### #+@

```ruby
+vector → Vector
```

This vector, unchanged. Included for symmetry with `#-@`; unary `+`
is conventionally a no-op in Ruby.

**Returns:**

- `Vector` — this same vector

**Defined in:** `example/lib/geometry/vector.rb:34`

### #-@

```ruby
-vector → Vector
```

The negation of this vector: same magnitude, opposite direction.

**Returns:**

- `Vector` — a new vector with both components negated

**Defined in:** `example/lib/geometry/vector.rb:24`

### #==

```ruby
vector == other → Boolean
```

Whether this vector has the same components as another.

Overrides `Data`'s own generated `==` purely to attach documentation
to it; the comparison itself (memberwise equality) is unchanged.

**Params:**

- `other` (`Object`) — the value to compare to

**Returns:**

- `Boolean` — `true` if `other` is a `Vector` with equal `dx` and `dy`

**Defined in:** `example/lib/geometry/vector.rb:47`

### #magnitude

```ruby
vector.magnitude() → Float
```

Computes the magnitude (length) of the vector.

**Returns:**

- `Float` — the magnitude

**Defined in:** `example/lib/geometry/vector.rb:15`
