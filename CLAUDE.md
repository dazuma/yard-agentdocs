# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

Basic gem scaffolding is in place (gemspec, `lib/`, `test/`, tooling), but no plugin behavior has been
implemented yet — `YARD::Agents` is currently an empty module. The design questions below are still open
and should be resolved before real implementation begins; update this file as they're settled.

## Purpose

`yard-agents` will be a Ruby gem implementing a [YARD](https://yardoc.org/) plugin. It provides a YARD
template that renders an "agent-friendly" yardoc output format: reference documentation structured for
consumption by coding agents (e.g. LLM-based tools) rather than for human browsing in a web browser.

The core problem being solved: agents that need to look up Ruby API details (method signatures, params,
return values, usage) currently have to search through source files or a human-oriented HTML yardoc site,
which burns a lot of input tokens and requires multi-step exploration. This gem should let an agent fetch
exactly the reference info it needs (e.g. one method's docs) with a single, cheap file read.

## Open design questions

These are not yet decided and should be resolved/documented here as they're settled:

- **Output format** — likely Markdown, but exact structure (headers, sections, front matter) is undecided.
- **File granularity** — one file per class vs. one file per method (to let an agent load a single method's
  docs without pulling in the whole class). Method-level granularity is the leading idea but has tradeoffs
  (file count, cross-references, shared class-level context like `@since`/inheritance).
- **Indexing/lookup** — how an agent (or tooling around it) discovers which file corresponds to a given
  class/method — e.g. a top-level index file, a predictable path/naming convention, or both.
- **YARD integration mechanics** — how the plugin hooks into YARD's template/handler system (custom
  template path vs. registered output format vs. `yard-*` plugin conventions) and how it's invoked
  (`yard doc -f agents`, a rake task, a CLI wrapper, etc.).
- **Cross-referencing** — how method docs that reference other methods/classes (`@see`, param types,
  return types, mixins/inheritance) should link between the generated files without forcing an agent to
  load unnecessary context.

## Commands

Tooling is driven by [Toys](https://dazuma.github.io/toys) (`gem install toys`), not Rake. Bundler is
wired into each tool, so none of these need `bundle exec`.

- `toys ci` — run the full CI suite (bundle, rubocop, tests, yardoc, gem build).
- `toys ci --only --test` — run a single CI job (any of `--bundle`, `--rubocop`, `--test`, `--yard`, `--build`).
- `toys test` — run the unit tests.
- `toys test test/test_version.rb` — run a single test file.
- `toys rubocop` — run the linter/style checker.
- `toys yardoc` — build docs. Fails on warnings and on any undocumented object, so every public
  class/module/method needs YARD comments.
- `toys build` / `toys install` — build (and install) the gem.

Run `toys test` and `toys rubocop` before committing.

## Architecture & conventions

- **Namespacing:** the gem is `yard-agents`; code lives under `YARD::Agents` (require path `yard/agents`),
  reopening the `YARD` module from the `yard` gem since this is a plugin for it. The entry point
  `lib/yard-agents.rb` just requires `yard/agents`. Mirrors the sibling gems' pattern of nesting the module
  under the gem name (see e.g. `ractor-wrapper` → `Ractor::Wrapper`).
- **Tests:** Minitest, spec-style (`describe`/`it` blocks with `assert_*` assertions, not `must`/`wont`
  expectations). Test files follow `test_*.rb`. `minitest-focus` is available — add `focus` above a test
  to run only that one.
- **Ruby support:** `required_ruby_version >= 3.4`. All files use `# frozen_string_literal: true`.
- **Docs as a gate:** `toys yardoc` fails on undocumented objects, so document public API as you add it.
- **Top-level constant references:** prefix references to Ruby core/stdlib and external-gem constants with
  a leading `::` (e.g. `::File`, `::Gem::Version`, `::YARD`), to avoid ambiguous resolution within nested
  namespaces. Do not prefix relative constants defined within the current namespace, and do not prefix
  Kernel method calls that look like constants (`Array(x)`, never `::Array(x)`).
- **License:** MIT.
