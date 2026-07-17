# class Geometry::Rectangle

- **Superclass:** `Object`
- **Defined in:** `example/lib/geometry/rectangle.rb`, `example/lib/geometry/rectangle_perimeter.rb`

An axis-aligned rectangle, defined by its width and height.

Its area and perimeter helpers live in separate files
(`rectangle.rb` and `rectangle_perimeter.rb`), the way a class's
methods might be split by concern across files in a real codebase.

## Member Summary

**Class Methods**

- `.new` — Creates a rectangle from its width and height.

**Instance Methods**

- `#area` — Computes the area of the rectangle.
- `#perimeter` — Computes the perimeter of the rectangle.

## Class Methods

### .new

*(Ruby's default constructor; documents `#initialize`.)*

```ruby
Rectangle.new(width, height) → Rectangle
```

Creates a rectangle from its width and height.

**Params:**

- `width` (`Float`) — the width
- `height` (`Float`) — the height

* **Defined in:** `example/lib/geometry/rectangle.rb:18`

## Instance Methods

### #area

```ruby
rectangle.area() → Float
```

Computes the area of the rectangle.

**Returns:**

- `Float` — the area

* **Defined in:** `example/lib/geometry/rectangle.rb:28`

### #perimeter

```ruby
rectangle.perimeter() → Float
```

Computes the perimeter of the rectangle.

**Returns:**

- `Float` — the perimeter

* **Defined in:** `example/lib/geometry/rectangle_perimeter.rb:10`
