---
name: yard-agentdocs
description: Look up Ruby API reference details — classes, modules, methods, signatures, parameters, return values — for a gem the project depends on. Use whenever you need to know how to use a gem's API, before reading gem source or searching the web.
---

# Ruby gem API lookup

**Dependencies only.** For the project you are editing, read its own source — that is
authoritative and already in front of you.

## The lookup

```
toys do --gem=yard-agentdocs --on-missing-gem=install agentdocs lookup <gem> <entity>
```

`<entity>` is a fully qualified name, optionally naming one member:
`Toys::Acceptor::Enum`, `Toys::Acceptor::Enum#initialize`, `Toys::Acceptor::Enum.new`,
`Toys::Acceptor::SOME_CONSTANT`. Quote it whenever an operator method name is involved —
`'Foo::Bar#[]='` — because those collide with shell metacharacters.

That one command resolves which version this project depends on, finds the file, cuts out
the section, and builds the documentation first if it doesn't exist yet. Run it outside
`bundle exec`. `--help` documents the remaining flags.

If `toys` is missing, run `gem install toys`. If that fails, stop using this skill and
read gem source instead — half-applying this is worse than not starting.

A first build of a large gem takes several minutes, so allow a generous timeout. A build
that gets killed leaves nothing half-finished behind, so just run the lookup again.

## Reading the answer

Everything you need is on standard output, including when the lookup can't be answered:
which version it read, where the gem's own source is, and what to do next. Do what it
says rather than picking from the candidate names it lists — those are candidates, not an
answer.

## When you don't have a name yet

The tool answers exact lookups only. With a fragment rather than a name, look up a
namespace you *do* know (`agentdocs lookup toys Toys`) and take the bundle directory from
the header it prints, then:

- `grep -i <term> <bundle>/index.md` — a class or module name you can't quite recall.
- `grep -rn '^### #method_name' <bundle>` — a member whose class you don't know.

Then look up the full name you found. Don't read `index.md` whole; on a large gem it is
very long.

## When to read source instead

When the tool says it can't answer: the gem isn't installed, or it's a git or path
dependency, or the name genuinely isn't documented. It prints the gem's own source
directory — read that.

Prefer local source to documentation on the web. If you do consult the web, confirm it
describes the version this project actually uses.
