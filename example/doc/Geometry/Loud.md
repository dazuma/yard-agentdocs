# module Geometry::Loud

- **Defined in:** `example/lib/geometry/loud.rb`

Prepended onto a class to upper-case whatever its own `#describe` method
returns, without needing to know that method's implementation.

Exercises `prepend`: unlike `include`, a `prepend`ed module's method
takes precedence over the prepending class's own same-named method — the
module sits *above* the class in the method resolution order — so the
class's own `#describe` is only reachable via `super`, from inside this
module's own override.

## Member Summary

**Instance Methods**

- `#describe` — Upper-cases the prepending class's own `#describe` result.

## Instance Methods

### #describe

```ruby
loud.describe() → String
```

Upper-cases the prepending class's own `#describe` result.

**Returns:**

- `String` — the class's own description, upper-cased

* **Defined in:** `example/lib/geometry/loud.rb:20`
