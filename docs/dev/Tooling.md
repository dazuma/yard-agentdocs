# Tooling decisions

Decisions about the user-facing tools this gem ships — the Toys tools under
`toys/` and the implementation classes behind them in `lib/yard/agentdocs/` —
recorded the way `DESIGN.md` records decisions about the output format, with a
dated section per decision and the rejected alternatives named so they aren't
re-proposed later.

**What this document is not.** It is not the decision log for the generated
format: that is `DESIGN.md`, whose scope stops at what the template produces.
It is not user documentation either — each tool's `long_desc` is that, and is
authoritative, because it cannot drift from the tool it is attached to. What
lives here is only the *why*: the trade-off that produced a flag, not what the
flag does.

## Skill installation (2026-09-12)

Adds `agentdocs install-skill`, which installs the agent skill shipped at
`skills/yard-agentdocs/` into a harness's skills directory. Before it, the
skill shipped in the gem with no way to get it anywhere useful —
`README.md`'s "Using agentdocs" section said to install it and left the
details as a TODO. Behavior lives in `YARD::AgentDocs::SkillInstaller`, with
the tool file holding only the Toys DSL and the prompt, as with the three
tools that preceded it.

**The artifact stays harness-neutral; the installer does not.** The skill was
deliberately written portable (see "Agent skill scope (2026-07-27)" in
`DESIGN.md`, which prioritized a single `SKILL.md` over harness-specific
affordances). A `--claude` flag does not violate that: `SKILL.md` still makes
no assumptions about who reads it, and knowing where Claude Code keeps its
skills is the installer's knowledge, held in one class method. This is the
boundary to defend if a second harness is ever added — harness knowledge
belongs in `SkillInstaller`, never in the skill's prose.

**Two destination flags, exactly one required.** `--claude` resolves the
well-known location; `--output DIR` names any other. Both treat their
directory as the one that *holds* skills, so the tool always writes a
`yard-agentdocs` subdirectory and the two flags differ only in path, never in
layout. Consequence worth stating: a project-scoped install needs no flag of
its own, since `--output .claude/skills` is exactly that. There is no default,
because both candidates — the current directory and the user's home — are
wrong about half the time, and a wrong default here writes files somewhere the
user didn't look.

The requirement is declared as a Toys `exactly_one` flag group rather than
checked in `run`. That is not only less code: it puts the constraint in
`--help` under its own heading, and makes violating it a usage error — usage
printed, exit 2 — instead of a bare message the tool invented on its own.

Note that the destination directory name is a convention, not a requirement:
Claude Code's frontmatter `name` wins over the directory basename, so an
install under any other name would still invoke as `yard-agentdocs`. Matching
the two is for the human reading `ls`, and a unit test pins the frontmatter
`name` to `SkillInstaller::SKILL_NAME` so a rename on one side can't silently
outrun the other.

**`$CLAUDE_CONFIG_DIR` relocates the whole configuration directory**, so the
skills directory is `$CLAUDE_CONFIG_DIR/skills`, not a separately configurable
path. Both this and the restart behavior below come from Claude Code's
documentation rather than from observed behavior — the one part of the path
contract taken on trust.

**Installing copies the directory, and replacing removes it first.** The skill
is one file today, but supporting files are a normal thing for a skill to
grow, and a tool that installs `SKILL.md` alone would install half of a future
skill without saying so. Replacement is `rm_rf` then copy, not a merge, for
the mirror-image reason: a file dropped from a later version of the skill
would otherwise survive the upgrade and still be read by the harness,
producing an install that is half one version and half another. The blast
radius is exactly the directory named after us, never the skills directory
containing it.

**Replacing prompts, defaulting to yes.** Re-running the tool after upgrading
the gem is the common case and should just work, so "skip if present" would be
the wrong default; but the installed file is editable prose, so silently
destroying a user's edits is the wrong default too. `--overwrite` and
`--no-overwrite` answer in advance.

**Unattended runs replace without asking, deliberately.** Toys'
`confirm(default: true)` returns its default at EOF rather than raising
(`toys-core` `lib/toys/utils/terminal.rb`: `ask` substitutes the default for an
empty response, and EOF reads as empty), so an agent, a CI job, or a piped run
takes the "replace" branch with nobody answering. That is the gem-upgrade path
working, and erroring instead would put a wall in front of exactly the
automation this gem exists to serve. It is the opposite call from
`agentdocs gems clean`, whose `confirm` defaults to *no* — the asymmetry is
intended: an unattended clean that guesses destroys bundles, while an
unattended install that guesses installs the thing that was asked for.

**Exit codes distinguish "declined" from "skipped."** Declining the prompt
prints `Cancelled.` and exits 1, matching `gems clean`: the user asked for
something and didn't get it. `--no-overwrite` over an existing install reports
it and exits 0, matching `--no-rebuild`: not writing *is* the requested
outcome.

**The source is located relative to `__dir__`**, not through
`Gem::Specification`. The gemspec route would fail in the case hit most often
during development — running the tool from a checkout of this repository,
where it would install a released gem's skill instead of the working copy's —
and buys nothing in the installed case, where `__dir__` is already inside the
gem.

**`SkillInstaller` follows `GemCleaner`'s shape, not `GemBuilder`'s.**
`GemBuilder` takes `rebuild:` as a constructor argument, but the overwrite
decision here is made *after* inspecting the destination, so the fitting shape
is the one `GemCleaner` uses for confirmation: construct, expose state
(`#destination`, `#installed?`, `#creates_output_root?`), then act
(`#install(overwrite:)`). The class stays non-interactive; the prompt lives in
the tool file, as `confirm_scope` does in `gems/clean.rb`.

**Considered and rejected:**

- **`--harness NAME` with a lookup table** instead of a boolean `--claude`.
  Rejected: it advertises knowledge of third-party layouts the gem doesn't
  have and can't test, and each entry becomes a maintenance liability against
  someone else's undocumented convention that can change without notice. A
  boolean flag per harness that actually matters, with `--output` covering
  everything else by hand, promises only what it can keep.
- **An `agentdocs skill install` namespace** (`toys/agentdocs/skill/install.rb`)
  for symmetry with `gems` / `gems clean`. Rejected: `gems` earned its
  namespace because `clean` is genuinely complex — version parsing, bulk
  selection, confirmation — while uninstalling a skill is removing one
  directory, which doesn't earn a subtool.
- **Gating the prompt on `$stdin.tty?`** and erroring out non-interactively
  without an explicit flag. Rejected per the unattended-run argument above.
- **Stamping provenance into the installed copy** so a later run could tell an
  untouched install from a locally edited one and only prompt for the latter.
  The principled answer, rejected on cost: it means either mutating the skill
  body — drift against the three-surface division of labor in `CONTEXT.md` —
  or writing a sidecar file inside a directory the harness scans, for a file
  the user can diff themselves.
- **Installing everything under `skills/`** so a second skill would need no
  tool change. Rejected, unlike the same argument applied to copying the skill
  *directory*, because this one isn't free: plural destinations branch
  `#destination`, `#installed?`, the prompt, and every message, for a case
  that doesn't exist. A second skill would be a deliberate design event with
  its own trigger and scope decision, and changing this tool would be the
  smallest part of that work.
- **Treating `--output` as the exact directory to write `SKILL.md` into**
  rather than as the containing skills directory. Rejected: it would make the
  two destination flags mean different kinds of path, which is the sort of
  asymmetry that only ever gets found by installing a skill somewhere inert.

## Atomic bundle publication (2026-09-15)

`agentdocs gems` documents each gem into a scratch directory under
`<output root>/.incomplete` and renames it to its canonical path only once
the build has finished. Before this, `GemBuilder#build_one` wrote straight
into the canonical path and removed it only when a build *returned* failure,
so a run killed partway — an agent's command timeout, a Ctrl-C, a SIGTERM —
left a partial tree that the next `--no-rebuild` run counted as finished, and
every later reader got silently incomplete documentation with nothing to tell
it apart from a complete bundle. The published contract is now that every
observable state of a canonical path is a complete bundle or nothing at all.
The same path carries `--rebuild`, so a failed rebuild no longer destroys the
bundle it was replacing. (Issue #3.)

**Rejected: cleaning up from a signal handler.** It answers Ctrl-C and
SIGTERM and nothing else — not SIGKILL, not a lost terminal, not the harness
reaping a process group — and a handler that deletes a partial tree can
itself be killed halfway through, which is the same bug one level down.

**Rejected: staging in the system temporary directory.** Publishing is a
rename, and a rename is only atomic within one filesystem; across one it
fails with `EXDEV` and forces a copy, which reintroduces exactly the
partially-visible state being designed out. The scratch directory has to live
inside the output root.

**Rejected: flat scratch names in the output root**, such as
`.tmp-rbs-3.10.0-4321`. `GemCleaner.parse_bundle_name` reads that as gem
`.tmp-rbs-3.10.0` at version `4321`, so scratch directories would surface as
bundles in `agentdocs gems clean` and skew its `--all-outdated` grouping. A
hidden container directory parses as no bundle at all, which is what keeps
the two tools from disagreeing about what is on disk; a unit test in
`test_gem_cleaner.rb` pins that.

**Rejected: delete-then-rename on a rebuild.** Deleting the old bundle first
leaves the canonical path missing for however long it takes to remove a tree
of several thousand files. Renaming it aside first shrinks that window to one
syscall, and leaves the old bundle intact to be restored if the publish then
fails.

**Rejected: pid liveness for the sweep.** Abandoned scratch directories are
swept by age (`STALE_TEMP_AGE`, 24 hours), not by asking whether the process
that created one is still running. A pid says nothing about a build started
on another machine sharing the same data home, and pids are reused; an age
threshold three orders of magnitude longer than the slowest build measured
needs neither assumption. The cost is that a killed build's scratch tree
occupies disk for up to a day, which is bounded and invisible.

**Rejected: lock files**, for mutual exclusion between builders or for sweep
liveness. Issue #3 scoped concurrency out and this keeps it out: two builders
racing one gem each publish a complete bundle and the last writer wins, so
the only cost is duplicated work, while a lock adds a stale-lock failure mode
that buys nothing else. Two mechanisms preserve that property rather than
relying on it being rare — a publish that loses the race retries once instead
of failing, and a sweep claims each candidate with a rename before deleting
it, so exactly one sweeper walks a given tree and a live build's scratch
directory is never taken out from under it.

**Not extended to `Builder`.** `agentdocs build` writes to a path the user
named, which may be on another filesystem and which the user may be watching;
the bug is about the canonical gems root, where the path is computed rather
than chosen and a reader has no way to judge what it finds.
