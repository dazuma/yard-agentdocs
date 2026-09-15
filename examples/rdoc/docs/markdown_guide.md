# @title A Markdown guide under --markup rdoc

# A Markdown guide under `--markup rdoc`

This guide's own extension, not the run's `--markup` flag, decides how it
is converted — the same rule YARD's default template applies to extra
files. So its Markdown reaches the page verbatim, even though every
docstring in this fixture is RDoc.

## A fenced block stays fenced

```ruby
Greeter.new("world").greet
```

## Markdown an RDoc reparse would rewrite

A *single-asterisk* span stays emphasis rather than becoming bold, and a
table stays a table rather than collapsing onto one line:

| File          | Dialect decided by    |
| ------------- | --------------------- |
| this guide    | its `.md` extension   |
| `README.rdoc` | its `.rdoc` extension |

Inline references still resolve: see {Greeter#greet}.
