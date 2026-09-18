# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Purpose

`yard-agentdocs` will be a Ruby gem providing an "agent-friendly" output format
(i.e. designed for consumption by coding agents rather than humans) for
[YARD](https://yardoc.org/) documentation, and corresponding tools for managing
a corpus of documentation and looking up information in it.

The core problem being solved: agents that need to look up Ruby API details
(method signatures, params, return values, usage) currently have to search
through source files or a human-oriented HTML yardoc site, which burns a lot of
input tokens and requires multi-step exploration. This gem should let an agent
fetch exactly the reference info it needs (e.g. one method's docs) with a
single, cheap shell command or file read. Note that this is a claim about the
cost of *one lookup*, and deliberately not about the size of the documentation,
which may still be of a comparable size to the original source code.

## Contents

The contents of this repo, along with links for getting more information:

- A YARD plugin that implements the output format itself. Located in the
  `templates/default/` directory, with support classes under `lib/`, unit tests
  under `test/`, and an example-based test suite under `examples/`.
  For information on working with the YARD plugin and templates, output format,
  and test suite, see [docs/dev/plugin-development.md](docs/dev/plugin-development.md).
- A set of command line tools that generate and manage a corpus of documentation
  and provide lookup capabilities. Located in the `toys/` directory, with
  support classes under `lib/` and unit tests under `test/`.
  For information on working with the command line tools, see
  [docs/dev/tools-development.md](docs/dev/tools-development.md).
- An agent skill that teaches an agent to use yard-agentdocs to look up Ruby
  library API information. Located in the `skills/yard-agentdocs/` directory.
  For information on working with the agent skill, see
  [docs/dev/skill-development.md](docs/dev/skill-development.md).
- Design and development workflow documentation located under `docs/`. Not
  included in the gem itself.

## Recording decisions

Architecture decision records live in [`docs/adr/`](docs/adr/), numbered sequentially.
The bar is deliberately high, and all three of these must hold: the decision is hard to
reverse, it is surprising without context, and it was a real trade-off with genuine
alternatives. Most decisions in this repository do not clear it, which is intended.

Everything else is recorded where the code it governs is:

- **A decision local to one class** belongs in that class's own YARD documentation, where
  anyone modifying the code will encounter it. Only an invariant spanning several classes,
  with no single home, is a candidate for an ADR.
- **A rendering decision** is recorded by the `examples/*/doc` fixture, which the test suite
  asserts byte for byte. Do not also restate it in prose. What a fixture cannot record — a
  rejected alternative someone would otherwise re-propose, a trap the tests do not catch —
  goes in a comment at the code that would break.
- **CLI mechanics** belong in the tool's `long_desc`, which cannot drift from the tool.
- **YARD's own quirks** are not decisions at all and are not ADR material. Ones with no
  code home go in [`docs/dev/YARD-notes.md`](docs/dev/YARD-notes.md).

Do not write a decision log. A second one alongside `docs/adr/` is a drift surface.

## Commands

Tooling is driven by [Toys](https://dazuma.github.io/toys), not Rake. Bundler is
wired into each tool, so none of these need `bundle exec`.

- `toys ci` — run the full CI suite (bundle, rubocop, tests, yardoc, gem build).
- `toys ci --only --test` — run a single CI job (any of `--bundle`, `--rubocop`, `--test`, `--yard`, `--build`).
- `toys test` — run the unit tests.
- `toys test test/test_version.rb` — run a single test file.
- `toys rubocop` — run the linter/style checker.
- `toys yardoc` — build docs. Fails on warnings and on any undocumented object, so every public
  class/module/method needs YARD comments.
- `toys build` — build the gem.

Run `toys test` and `toys rubocop` before committing.

## Conventions

- **Namespacing:** the gem is `yard-agentdocs`; code lives under `YARD::AgentDocs` (require path
  `yard/agentdocs`), reopening the `YARD` module from the `yard` gem since this is a plugin for it. The
  entry point `lib/yard-agentdocs.rb` just requires `yard/agentdocs`. Note this deliberately departs from
  the mechanical gem-name-to-module convention (`yard-agentdocs` would mechanically map to
  `YARD::Agentdocs`) for readability — same manual override RuboCop makes (`rubocop` → `RuboCop`, not
  `Rubocop`).
- **Tests:** Minitest, spec-style (`describe`/`it` blocks with `assert_*` assertions, not `must`/`wont`
  expectations). Test files follow `test_*.rb`. `minitest-focus` is available — add `focus` above a test
  to run only that one.
- **Ruby support:** `required_ruby_version >= 3.4`. All files use `# frozen_string_literal: true`.
- **Docs as a gate:** `toys yardoc` fails on undocumented objects, so document public API as you add it.
- **Changelog:** `CHANGELOG.md` is updated automatically by the release process. Never edit it as part
  of a task, and don't propose editing it.
- **Top-level constant references:** prefix references to Ruby core/stdlib and external-gem constants with
  a leading `::` (e.g. `::File`, `::Gem::Version`, `::YARD`), to avoid ambiguous resolution within nested
  namespaces. Do not prefix relative constants defined within the current namespace, and do not prefix
  Kernel method calls that look like constants (`Array(x)`, never `::Array(x)`).

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues (`dazuma/yard-agentdocs`), via the `gh` CLI.
See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, each label string equal to its name.
See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` plus `docs/adr/` at the repo root.
See `docs/agents/domain.md`.
