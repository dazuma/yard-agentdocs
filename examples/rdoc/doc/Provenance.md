---
type: Ruby Class
title: Provenance
description: "Exercises RBS provenance-marker stripping."
---

# class Provenance

- **Superclass:** `Object`
- **Defined in:** `examples/rdoc/lib/provenance.rb`, `examples/rdoc/sig/provenance.rbs`

Exercises RBS provenance-marker stripping.

The single-line Form A marker above must not reach the rendered body, the
`description` frontmatter, or the `index.md` entry.

RBS emits a marker at the head of every doc comment it imports from RDoc. See
issue #1.

## Member Summary

**Instance Methods**

- `#render` — Renders `text`.
- `#width` — Declared only in the signature file.

## Instance Methods

### #render

```ruby
provenance.render(text) → String
```

Renders `text`.

The multi-line Form B marker above carries RDoc call-seq lines. Left
unstripped, they render as a stray indented code block.

**Params:**

- `text` (`String`)

**Returns:**

- `String`

* **Defined in:** `examples/rdoc/lib/provenance.rb:16`

### #width

```ruby
provenance.width() → Integer
```

Declared only in the signature file.

Its docstring has no Ruby-source counterpart to override, which is the shape
`Prime.each` has.

**Returns:**

- `Integer`

* **Defined in:** `examples/rdoc/sig/provenance.rbs:26`
