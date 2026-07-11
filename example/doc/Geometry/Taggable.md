# module Geometry::Taggable

**Defined in:** `example/lib/geometry/taggable.rb`

Mixed into shape classes to add a short bracketed tag string, derived
from whatever `#label` the including class defines.

Exercises a plain `include` of a module defining instance methods: the
including class's own file shows an `**Includes:**` line pointing back
here, rather than duplicating `#tag`'s docs inline.

## Member Summary

**Instance Methods**

- `#tag` — A short tag for the shape, derived from its label.

## Instance Methods

### #tag

```ruby
taggable.tag() → String
```

A short tag for the shape, derived from its label.

**Returns:** `String` — the label wrapped in brackets, e.g. `"[circle]"`

**Defined in:** `example/lib/geometry/taggable.rb:18`
