# class Greeter

**Superclass:** `Object`
**Defined in:** `example/rdoc/lib/greeter.rb`

Builds a greeting string. Written in **RDoc** markup instead of Markdown, to
exercise the `rdoc` dialect of the "Docstring markup dialect" decision. See
the [RDoc markup reference](https://ruby.github.io/rdoc/RDoc/Markup.html) for
the full grammar. Also proves inline cross-reference resolution runs after
RDoc conversion: this paragraph's bare `Greeter#greet` reference resolves, but
renders as a plain, unlinked name — a same-file self-reference.

## Member Summary

**Instance Methods**

- `#greet` — Greets `name`, wrapping it in *emphasis*.

## Instance Methods

### #greet

```ruby
greeter.greet(name) → String
```

Greets `name`, wrapping it in *emphasis*.

**Params:**

- `name` (`String`) — the `name` to greet

**Returns:**

- `String` — the greeting, with `name` emphasized

**Defined in:** `example/rdoc/lib/greeter.rb:19`
