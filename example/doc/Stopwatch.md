# class Stopwatch

**Superclass:** `Object`
**Defined in:** `example/lib/stopwatch.rb`

A simple stopwatch that accumulates elapsed time, in seconds.

Defined at the top level (not nested inside any module), to exercise how
`yard-agentdocs` renders a class that isn't namespaced.

Call the reset method to start over.

## Member Summary

**Constants**

- `DEFAULT_ELAPSED` — The elapsed time a newly created stopwatch starts at, and the default value `#reset` resets to.

**Class Methods**

- `.new` — Creates a stopwatch with no elapsed time yet recorded.

**Instance Methods**

- `#add` — Adds to the elapsed time.
- `#describe` — Builds a descriptive label for this stopwatch.
- `#measure` — Runs the given block and adds how long it took to this stopwatch's elapsed time.
- `#reset` — Resets the elapsed time.

## Constants

### DEFAULT_ELAPSED

**Type:** `Float`
**Value:** `0.0`

The elapsed time a newly created stopwatch starts at, and the default
value `#reset` resets to.

**Defined in:** `example/lib/stopwatch.rb:18`

## Class Methods

### .new

*(Ruby's default constructor; documents `#initialize`.)*

```ruby
Stopwatch.new() → Stopwatch
```

Creates a stopwatch with no elapsed time yet recorded.

**Defined in:** `example/lib/stopwatch.rb:23`

## Instance Methods

### #add

```ruby
stopwatch.add(seconds) → Float
```

Adds to the elapsed time.

**Params:**

- `seconds` (`Float`) — the number of seconds to add

**Returns:** `Float` — the new total elapsed time

**Defined in:** `example/lib/stopwatch.rb:33`

### #describe

```ruby
stopwatch.describe(name, precision = 1, *tags, unit:, separator: ", ", **metadata, &block) → String
```

Builds a descriptive label for this stopwatch. Combines every parameter
shape this format's signature line can render — a required positional
argument, an optional positional argument, a splat, a required keyword,
an optional keyword, a double-splat, and a block — in one signature,
purely to exercise how they assemble together; not a realistic
formatting API.

**Params:**

- `name` (`String`) — the stopwatch's label
- `precision` (`Integer`) — decimal places to round the elapsed time to
- `tags` (`Array<String>`) — extra tags to include
- `unit` (`String`) — the unit label, e.g. `"s"`
- `separator` (`String`) — the string used to join the tags
- `metadata` (`Hash{Symbol => Object}`) — arbitrary extra key/value pairs to include
- `block` (`Proc`) — a block to post-process the label, used instead of it if given

**Returns:** `String` — the assembled label

**Defined in:** `example/lib/stopwatch.rb:79`

### #measure

```ruby
stopwatch.measure(&block) → Object
```

Runs the given block and adds how long it took to this stopwatch's
elapsed time.

**Yields:** the work to time

**Yield Returns:** `Object` — the block's own return value, passed through unchanged

**Returns:** `Object` — the block's return value

**Defined in:** `example/lib/stopwatch.rb:55`

### #reset

```ruby
stopwatch.reset(to = DEFAULT_ELAPSED) → Float
```

Resets the elapsed time.

**Params:**

- `to` (`Float`) — the elapsed time to reset to; defaults to `DEFAULT_ELAPSED`

**Returns:** `Float` — the new elapsed time

**Defined in:** `example/lib/stopwatch.rb:43`
