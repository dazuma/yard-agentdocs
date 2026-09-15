---
type: Ruby Class
title: BlockMarkup
description: "Exercises the block constructs RDoc's own markup gives no meaning to."
---

# class BlockMarkup

- **Superclass:** `Object`
- **Defined in:** `examples/rdoc/lib/block_markup.rb`

Exercises the block constructs RDoc's own markup gives no meaning to.

`RDoc::Markup` joins consecutive unindented lines into one paragraph, so a
fenced code block, a table, or a Markdown blockquote written in an
RDoc-dialect docstring collapses onto one line unless the converter passes it
through untouched. A fence collapsed that way also takes the rest of the page
with it, since the stray backticks leave an apparently-open code block.

```ruby
## A Ruby comment, not a structural heading.
BlockMarkup.new.render(Greeter.new)  # {Greeter#greet} stays literal here
```

| Construct  | Meaning in RDoc | Passed through |
|------------|-----------------|----------------|
| Fence      | none            | yes            |
| Table      | none            | yes            |
| Blockquote | none            | yes            |

> A Markdown blockquote keeps its own line breaks,
> so this stays two quoted lines.

Everything RDoc **does** give a meaning to still converts. The [`Greeter`](Greeter.md)
reference in this sentence resolves, and a verbatim block stays verbatim even
when its content opens with a fence:

    ```ruby
    not_a_fence = true
    ```

and `>>>`, not `>`, is RDoc's own blockquote marker:

> Quoted by RDoc, converted rather than passed through.

## Member Summary

**Instance Methods**

- `#render` — Renders `greeter`'s greeting as a fenced block.

## Instance Methods

### #render

```ruby
blockmarkup.render(greeter) → String
```

Renders `greeter`'s greeting as a fenced block.

```text
Hello, world!
```

**Params:**

- `greeter` ([`Greeter`](Greeter.md)) — the greeter to render

**Returns:**

- `String` — the rendered block

* **Defined in:** `examples/rdoc/lib/block_markup.rb:51`
