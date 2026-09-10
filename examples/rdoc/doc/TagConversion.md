---
type: Ruby Class
title: TagConversion
description: "Exercises RDoc::Markup::ToMarkdown's raw-HTML-leak bug."
---

# class TagConversion

- **Superclass:** `Object`
- **Defined in:** `examples/rdoc/lib/tag_conversion.rb`

Exercises RDoc::Markup::ToMarkdown's raw-HTML-leak bug.

A character outside plain word characters or whitespace, inside any styled
delimiter, converts to literal HTML instead of the equivalent Markdown span —
see "RDoc::Markup::ToMarkdown raw-HTML leaks" under "Decisions" in
docs/dev/DESIGN.md. Covers the plain shorthand (`word`, `word`, **word**,
*word*) and the HTML-ish tag form (<tt>, <code>, <b>, <i>, <em>, <s>, <del>)
alike.

Punctuated shorthand: `valid?`, `save!`, `name=`, `Foo::Bar`, `x[0]`,
**bold?**, *em!*.

Punctuated tag form: `=~`, `a.b`, **foo=~bar**, *a.b*, *foo!*, ~~strike!~~,
~~del?~~.

Nested styled content — multiple inline nodes inside one styled tag, not just
punctuated single-string content: **foo **bar** baz**, *foo **bar** baz*,
~~foo **bar** baz~~. `foo <b>bar</b> baz` looks similar but isn't: RDoc's own
parser captures tt/code content as one literal string, never nested nodes, so
it already rendered correctly before this fix.

A verbatim example — the literal angle-bracket text below must survive
untouched, unlike the prose above:

    example_code = "<code>literal</code>"
    another_line <tt>also literal</tt>

## Member Summary

**Instance Methods**

- `#name=` — Sets the receiver's `name=`.
- `#save!` — `save!` persists the receiver, raising on failure.
- `#valid?` — Returns whether the receiver is `valid?`.

## Instance Methods

### #name=

```ruby
tagconversion.name = value
```

Sets the receiver's `name=`.

**Params:**

- `value` (`String`) — the new name

* **Defined in:** `examples/rdoc/lib/tag_conversion.rb:55`

### #save!

```ruby
tagconversion.save!() → void
```

`save!` persists the receiver, raising on failure.

**Returns:**

- `void`

* **Defined in:** `examples/rdoc/lib/tag_conversion.rb:47`

### #valid?

```ruby
tagconversion.valid?() → Boolean
```

Returns whether the receiver is `valid?`.

**Returns:**

- `Boolean` — whether valid

* **Defined in:** `examples/rdoc/lib/tag_conversion.rb:38`
