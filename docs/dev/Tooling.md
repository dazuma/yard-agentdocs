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

## The `agentdocs lookup` Reader (2026-09-15)

Adds `agentdocs lookup <gem> <entity>`, which answers one API lookup against a
gems bundle and writes the single member or concept asked for to standard
output. It is the **Reader** `CONTEXT.md` already defined, and its behavior
lives in three classes — `Lookup` (orchestration, provenance, exit codes),
`BundleReader` (the format mechanics), and `DependencyResolver` (which version,
installed where) — with `toys/agentdocs/lookup.rb` holding only the Toys DSL
and the prompt, as with the four tools that preceded it. (Issue #4.)

**Why a Reader at all: correctness, not token economy.** Before this, roughly
70% of `SKILL.md` was `bundle.md`'s mechanics restated as prose — path
derivation, the heading grammar, the XDG path, version resolution from
`Gemfile.lock` — which is exactly the duplication the three-surface division of
labor exists to prevent. The problem isn't the length. It's that the skill's
highest-stakes lines ("never read a different version's tree", "never `--all`",
"never read `index.md`") are unenforceable in prose and are invariants in code.
A prose file cannot *execute* the preamble's mechanics, only paraphrase them.
Collapsing a three-or-four-turn lookup into one is the secondary benefit.

**Three classes, not one.** They have different owners and different failure
domains: format mechanics belong with the format, project dependency resolution
belongs with Bundler's conventions, and the shape of an answer belongs with the
caller. The `agentdocs search` follow-up (issue #5) reuses the first two
unchanged. `Lookup#run` returns a `Result` value object rather than the boolean
`GemBuilder#build` returns, because here the body *is* the product.

**Accelerator, never gateway.** The Reader implements the preamble rather than
restating it, so the two cannot disagree; reading a bundle with `grep` stays a
first-class path; and a Reader bug degrades to "grep still works." The body is
reproduced verbatim — in particular `**Defined in:**` paths are *not* rewritten
to absolute ones, which would make this a transformer and leave `bundle.md`
describing something other than what the agent sees. The gem root is printed in
the header instead, which is free (the spec is already resolved) and removes the
`bundle show` hop the old skill documented.

**No fence tracking; the heading grammar does the work instead.** Section
boundaries are found by line prefix. Measured across the 7,472 class/module
files in a 117-bundle local corpus, no `## ` or `### ` line inside a closed
fence was ever anything but the document's own structure — zero real cases to
defend against — while 57 files *would* be misread by a fence tracker: 47 carry
generated markdown whose stray backticks open a fence that swallows the rest of
the document (all of `erb-6.0.7/ERB.md`'s structure, for one), and 10 `rbs`
files have genuinely unbalanced fences. What a fence tracker would have caught
is caught more cheaply by holding `### ` lines to the grammar itself: a member
name never contains a space, across all 16,971 distinct headings in the corpus,
so a prose heading inside an `@example` block is rejected without the failure
mode. `# ` is never a boundary — `# good` / `# bad` comments inside rubocop's
examples match it thousands of times.

**A member is presented with its type's flags, not just its ancestry.** The
head reproduced above a `### ` section runs from the `# class Foo::Bar` heading
through the `- ` context bullets (superclass, mixins, source file) *and* the
`* ` flags below them — `Deprecated.`, `Private API.`, `Abstract.`, `Note:`,
`Since:`, on 329 of the corpus's 7,472 concepts. Stopping at the context
bullets, as this first did, would present a method of a deprecated or private
class as though it were ordinary API, which is a wrong answer rather than a
short one. The boundary is the class docstring, and the marker is what tells
the two apart: no concept in the corpus opens its docstring with a bullet. The
head is *sliced* out of the file rather than reassembled from the lines that
matched, so the blank line separating the `- ` block from the `* ` block — the
thing that keeps them rendering as two lists rather than one, per `bundle.md`'s
own note on the marker change — survives verbatim. Items carry their indented
continuation lines, which a long `**Includes:**` list or a multi-line
`**Deprecated.**` note needs.

**A concept is read to the end of `## Member Summary`, delimited by the first
`## ` that *follows* it.** Not the first `## ` in the file: 6 corpus files write
their own `## ` headings in a class docstring, which land above Member Summary
and would cut those concepts off before they said anything. 679 files have
Member Summary as the last heading and 556 have no heading at all; both read
whole. There is no byte threshold and no truncation marker — the shape of the
output is a property of the request, not of the file's size.

**Version resolution is the point.** It is the most mechanical and most
error-prone step of a lookup, and leaving it to the caller would have preserved
the exact failure this tool removes. `$BUNDLE_GEMFILE` first, else the nearest
lockfile walking up from the current directory, else the newest installed
version, and `--version` over all of it. Walking up matches Bundler, so the tool
agrees with `bundle exec` run from the same place; resolving only against the
current directory would silently fall back to "newest installed" whenever an
agent had moved into `lib/`. A vendored bundle path (`bundle config path
vendor/bundle`) is searched ahead of the global gem directory — the gem *is*
installed there, just not where `GemBuilder.default_spec_dirs` looks, and this
is the real gap that "auto-install" was reaching for.

**`--version` settles even a git or path dependency**, bypassing the lockfile
entirely. Naming a version is itself the statement that a released version is
wanted, the same way naming a gem is the statement of intent in `GemBuilder`.

**The body is primary; exit codes are secondary.** An LLM caller reads standard
output and mostly ignores `$?`, so every failure's body carries the next move —
which file to read instead, which command to run, where the gem's own source is.
`0` success, `1` not found, `2` usage (Toys' own convention), `3` no released
version to document, `4` build failed. A missing bundle under `--no-build` is
`1`, with the build command spelled out: the entity was not found, and there is
no fifth case to invent for it.

**An exact lookup never falls back to a fuzzy one.** A guess that reads as an
answer is the failure this tool exists to eliminate. A miss lists candidates,
labelled as candidates, and says so in as many words.

**`Foo::Bar::BAZ` is retried as a constant, and the file always wins.** A
constant is written exactly like a nested class, so a name with no member and no
file of its own is looked for as a constant of its own namespace; `Foo/Bar/Baz.md`
existing settles it as the nested class. The constant's heading is confirmed
*before* the retry is accepted rather than left to the section extraction, because
`--full` prints a whole file without extracting anything, and answering a missing
constant with its namespace's entire file is precisely the plausible-wrong-answer
shape. When neither reading resolves, both are reported, with both candidate sets.

**Build progress goes to standard error.** `YARD::Logger.instance` writes to
standard output by default (`yard/logging.rb`), so `log.io` is swapped for the
duration of a build and restored afterwards. Otherwise parse progress and
per-gem announcements would land in the middle of what an agent is about to read
as documentation.

**Considered and rejected:**

- **Installing the subject gem** when it isn't installed. Permanently installing
  arbitrary third-party code on an agent's behalf, to answer a documentation
  question, is out of proportion — and the motivating case mostly isn't real,
  since a gem in `Gemfile.lock` is nearly always already installed. Installing
  `yard-agentdocs` and `toys` themselves is already handled by
  `toys do --gem=… --on-missing-gem=install` and `gem install toys`.
- **Embedding the lookup as a script inside `SKILL.md`.** `install-skill` copies
  the directory and freezes it, so a stale copy would go on misreading newer
  bundles with nothing to say it had drifted. The tool ships with the gem that
  generates the format.
- **Byte-threshold truncation** of a large concept, with a marker. Rejected: the
  shape of the output would then depend on the file rather than on the request,
  and an agent could not tell a complete answer from a clipped one without
  checking for the marker. `--full` is the explicit escape.
- **Fuzzy fallback on an exact miss** — nearest-name matching, case folding,
  sigil-insensitive matching. Rejected per the invariant above.
- **Rewriting the `Defined in:` lines to absolute paths.** Rejected per the
  verbatim rule above.
- **Bundle-wide candidate headings on a member miss** — grepping every concept
  for `### <member>`. Rejected as too wide for what a miss is for: the
  inherited-and-mixed-in pointer is exact and one hop, the concept's own member
  list is local, and `bundle.md`'s own `grep -rn '^### #name' .` recipe covers
  the rest without this tool guessing at scope. Discovery is issue #5's job.
- **Fence-aware section extraction.** Rejected on the 7,472-file measurement
  above: strictly worse than line-prefix matching on real bundles.
- **`Bundler::LockfileParser`** instead of a sectional text parse. Rejected: the
  tool is documented to run *outside* `bundle exec` precisely because the gems it
  can document are the ones on the machine rather than the ones one bundle
  activated, and loading Bundler to answer a question about the bundle it is not
  in is how that distinction gets lost. What is needed is a few dozen lines, and
  `GemBuilder` already globs specifications rather than reading
  `Gem::Specification.stubs` for the same reason.
- **Build locking** between concurrent lookups. Out of scope per issue #3, which
  established that two builders racing one gem each publish a complete bundle and
  the last writer wins; a lock adds a stale-lock failure mode and buys nothing.
- **A `docs/adr/` entry** for any of this. Rejected on the same grounds
  `DESIGN.md` rejected it on 2026-09-12: this repository already has a decision
  log, and a second one is a drift surface. This section plus the tool's
  `long_desc` are the record.

## The `agentdocs path` subtool (2026-09-15)

Adds `agentdocs path <gem>`, which writes the directory of a gem's gems bundle
to standard output as a single bare line and nothing else. (Issue #10, split
out of the design discussion on #5 as separable from `search` and not blocked
on any of its open questions.)

**Why a subtool exists for one line of output.** `CLAUDE.md` holds that `lookup`
is an accelerator and never a gateway: grepping a bundle directly stays
first-class, and the format, not the Reader, is the contract. But there was no
cheap way to *enter* that first-class path. A bundle lives at `<XDG data
home>/yard-agentdocs/gems/<name>-<version>`, and an agent cannot derive it — it
does not know which version the project resolves, and should not be
reimplementing XDG resolution. So every direct grep began by spending a whole
`lookup` on a namespace the agent already knew, purely to read the bundle
directory out of the `Bundle:` header and discard the rest: 3.1 KB for
yard-0.9.45, 7.3 KB for rubocop-1.90.0, 26 KB for prism-1.9.0.

**The property bought is composability, not tokens.** Being precise, because the
first draft of this argument overstated it: a path-only command does not remove
a tool call, it replaces a fat one with a thin one, and that saving is real but
modest. What a bare line buys that a prose header cannot is that it can sit
inside `$( )` — one Bash invocation doing resolution and grep together, where
reading a header necessarily costs two round trips because the agent must read
it with its own eyes before it can issue the grep. The token saving falls out as
a side effect. The stronger justification is the principle: first-class direct
grep had no cheap entry point, which was a gap in a property the project had
already committed to.

**A subtool, not a `--path-only` flag on `lookup`.** `lookup` takes `ENTITY` as a
`required_arg` and a path query has no entity; a flag would make a required
argument meaningless and force a hand-rolled conditional in `run` where Toys
expresses the split declaratively. `lookup`'s contract is untouched.

**Standard output is inverted relative to `lookup`, deliberately.** `Lookup`'s
rule is that the body is primary and every explanation — including every
failure — goes to standard output, because an LLM caller reads stdout and
ignores `$?`. `BundlePath` cannot do that: one stray line of prose and `$( )`
yields a path that is not a path. So standard output carries the directory and a
newline or it carries nothing at all, every diagnostic goes to standard error
(where an agent still sees it, since harnesses present both streams), and the
exit code carries the outcome.

**A successful run says nothing at all beyond the path.** An earlier draft also
reported the resolved version and its origin (`yard 0.9.45 (from Gemfile.lock)`)
on standard error, reasoning that "never read a different version's tree" is the
invariant this family exists to enforce and that the path names the version but
not where it came from. Rejected as noise: it printed on every single run, in a
tool whose whole purpose is to be composed with a command whose output is what
the caller actually came for. `lookup` still states its provenance, because
there the body *is* the product and the header sits above it; here the product
is one path, and the directory ends in the resolved version already.

A **path dependency** is the case that makes the rule worth stating rather than
assuming. There *is* a real directory on disk for it, and printing that would be
the single most tempting way to make `"$docs_dir"/index.md` name something that is not
a bundle. A line on standard output means a bundle is at that location and means
nothing else.

**Missing bundles are built, exactly as `lookup` builds them.** The alternative —
report but never build — was considered and rejected: it makes the composed form
fail precisely in the cold-start case, which is the round trip that costs most,
and two sibling subtools with opposite defaults for the same situation is a
drift surface the skill would then have to explain. The objection that building
is surprising inside `$( )` is answered by the stream split: build progress
already goes to standard error, so a build there is slow, not wrong. `--no-build`
keeps standard output empty and reports the build command on standard error.

**Every published recipe gates the grep on the exit status.** Not
`grep -i flag "$(agentdocs path toys)"/index.md` but:

```
docs_dir=$(toys do --gem=yard-agentdocs --on-missing-gem=error agentdocs path toys) &&
  grep -i flag "$docs_dir"/index.md
```

A command substitution that fails prints nothing, so the ungated form goes on to
search `/index.md` at the root of the filesystem. Verified against the real tool:

```
$ sh -c 'grep -ic tag "$(toys agentdocs path nonesuch-gem)"/index.md'
gem `nonesuch-gem` is not installed, so there is no bundle for it.
grep: /index.md: No such file or directory
$ sh -c 'docs_dir=$(toys agentdocs path nonesuch-gem) && grep -ic tag "$docs_dir"/index.md'
gem `nonesuch-gem` is not installed, so there is no bundle for it.
```

Today that failure is merely noisy, because nothing is at `/index.md`. The `&&`
is what makes the failure path *unreachable* rather than loud, and it costs one
shell operator. `test/test_bundle_path.rb` drives the class through a real shell
to pin it.

**Both parts of that first line are documented with their consequences, not as
bare prohibitions.** "Do not modify the first line" does not survive contact with
a reason to modify it, and the agent will have one: when resolution fails the
error is `Could not find 'yard-agentdocs' … among 164 total gem(s)`, and the
skill itself demonstrates `--on-missing-gem=install` three sections above.
Switching `error` to `install` is the obvious, helpful-looking repair and it
reintroduces exactly what the flag prevents. Likewise "`$docs_dir` will be empty"
reads as *harmless*, where "`grep` will read `/index.md` at the root of the
filesystem" does not. Each rule names what it prevents.

**`--on-missing-gem=error` is required inside a command substitution**, and this
is a sharper hazard than it looks. `toys do --gem=` activates the gem before the
tool runs, and the activation path is
`Toys::Utils::Exec.new.exec(["gem", "install", …])` (toys-core
`lib/toys/utils/gems.rb`), whose foreground default is `:inherit` on both
streams — so `gem install`'s "Successfully installed…" chatter lands on the
parent's standard output, inside `$( )`. Worse, the *default* policy is
`:confirm`, and `Toys::Utils::Terminal#confirm` writes its prompt to the
**output** stream and, at EOF on standard input, takes the default and answers
yes (`#ask` returns `default.to_s` on an empty read). Probed directly:

```
$ ruby -e 't.confirm("Gem needed: ... Install? ", default: true)' </dev/null
STDOUT: [Gem needed: "yard-agentdocs". Install? (Y/n) ]
STDERR: [confirm returned: true]
```

So in a non-interactive agent shell the default does not merely prompt: it
pollutes `$( )` with the prompt text, silently installs, and adds the install
chatter. `SKILL.md`'s main `lookup` command keeps `--on-missing-gem=install`,
since it is not inside a substitution and is the intended bootstrap; a composed
recipe that errors for want of the gem is recovered with a plain
`gem install yard-agentdocs`, parallel to the `gem install toys` the skill
already prescribes.

**The skill's recipe points at `bundle.md`, which is the real reason this
section of it got shorter rather than longer.** An agent that needs to grep for
something the two recipes don't cover is told to read `"$docs_dir"/bundle.md` —
the Preamble, the surface `CONTEXT.md` puts in charge of format mechanics. So
`path` turns out to be an entry point to the Preamble and not merely to
`index.md`, and the skill can answer an open-ended format question by delegating
instead of accreting a third and fourth grep recipe, which is the drift pressure
this section has always been under. It is cheap advice: `bundle.md` is exactly
1,991 bytes in all 114 current bundles in the local corpus, identical in each
(the only two without it are stale `toys-0.22.0` trees built before it existed),
so "read it whole" costs a fixed ~2 KB. The recipe also ends by sending the
agent back to `lookup` with the name it found — the section teaches discovery,
and `lookup` is still the thing that cuts out one section and states its
version.

**`BundleLocator`, extracted rather than duplicated.** `Lookup#run`'s first half —
validate the name, resolve the version, derive the directory from the resolved
spec, confirm it is there, build it if allowed — is the entire mechanism
enforcing "never read a different version's tree." Two callers would have made
duplication defensible; the third settles it, since `search` (#5) needs the
identical sequence and three independent transcriptions of an anti-drift
invariant is the worst possible place for a copy. The seam is thin: `#locate`
returns a `Location` carrying a status, a directory, and the resolution, and
**no message text at all**, because the callers differ precisely in how they
speak. Nothing in it reads a bundle, which is what lets `BundlePath` depend on it
without depending on the format at all. `test/test_lookup.rb` was not touched,
and passing unchanged is the refactor's proof.

**`ExitCodes` is a mixin, and nested `Result` classes must qualify it.** The five
codes moved off `Lookup` into a module both classes include, so there is one
definition of a taxonomy two tools share. Scoped access (`Lookup::EXIT_SUCCESS`)
still resolves, because that form searches ancestors — but the *lexical* lookup
inside the nested `Result` does not search the enclosing class's ancestors, so
`Result#success?` names `ExitCodes::EXIT_SUCCESS` explicitly. `Lookup`'s own test
suite caught this, which is the second argument for having left it untouched.

**Considered and rejected:**

- **Printing the path without checking the bundle is there** — pure arithmetic,
  no filesystem access. Rejected: a path to a directory that does not exist is
  the plausible-wrong-answer shape this project rejects everywhere else, and it
  makes the composed grep fail for a reason the caller cannot diagnose from the
  output.
- **A way to get the gem's own source root** — `path --gem-root`, or an
  `agentdocs gem-root` subtool. Nearly free, since the spec is already resolved,
  and there is a real workflow behind it, because "read the gem's own source
  instead" is how every `lookup` failure ends. Rejected anyway: it is a different
  question ("where is this gem installed") that existing tools already answer
  (`bundle show`, `gem which`), whereas nothing but this can answer "where is
  this gem's bundle" — and folding both into one subtool would break the
  invariant above, since the same line on standard output would sometimes mean a
  bundle and sometimes a source tree. Recorded because it will look like an
  obvious win to whoever picks up #5.
- **Naming it `bundle`, `bundle-dir`, or `where`.** `CONTEXT.md` reserves bare
  "bundle" against Bundler collision in agent-facing prose, and `path` is the
  shortest thing that reads correctly at the call site, which is the whole point.
- **Teaching the skill nothing and leaving the old two-step recipe.** Rejected:
  the recipe existed *because* this command did not, and replacing it removes a
  mechanic from the skill rather than adding one, which is the direction
  `CONTEXT.md`'s division of labor pushes.
- **A `docs/adr/` entry.** Same grounds as every section above it: this file is
  the decision log, and a second one is a drift surface.
