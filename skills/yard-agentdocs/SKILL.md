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

## When you don't have an exact name

The lookup tool answers exact lookups only. If you need to search for a term or a name
fragment, resolve the gem's docs directory and grep within it in one command.

For example, to find a class or module name given a name fragment or a term in its
description summary, use:

```
docs_dir=$(toys do --gem=yard-agentdocs --on-missing-gem=error agentdocs path <gem>) &&
  grep -i <term> "$docs_dir"/index.md
```

If you have a method name but not the class, replace the grep in the second line with
`grep -rn '^### #method_name' "$docs_dir"`. Once you have a full name, look it up — that
is the command that cuts out the one section you want and says which version it read.

Do not modify the first line that resolves `$docs_dir`. `--on-missing-gem=error` is what
keeps an install prompt out of `$docs_dir`, and the `&&` is what stops a failed
resolution leaving `grep` to read `/index.md` at the root of the filesystem.

You can replace the second line to grep for a variety of different things. If you need
more information about the format of the documentation to determine how to grep, read
`"$docs_dir"/bundle.md`.

The directory resolution will yield a nonzero exit code and print a message to stderr on
failure. If it errors because `yard-agentdocs` isn't installed, you can recover by running
`gem install yard-agentdocs` to install it.

## When to read source instead

When the tool says it can't answer: the gem isn't installed, or it's a git or path
dependency, or the name genuinely isn't documented. It prints the gem's own source
directory — read that.

Prefer local source to documentation on the web. If you do consult the web, confirm it
describes the version this project actually uses.
