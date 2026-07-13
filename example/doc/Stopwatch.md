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

### #reset

```ruby
stopwatch.reset(to = DEFAULT_ELAPSED) → Float
```

Resets the elapsed time.

**Params:**

- `to` (`Float`) — the elapsed time to reset to; defaults to `DEFAULT_ELAPSED`

**Returns:** `Float` — the new elapsed time

**Defined in:** `example/lib/stopwatch.rb:43`
