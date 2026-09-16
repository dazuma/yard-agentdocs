# Gems bundles publish atomically; concurrent builds are last-writer-wins

## Context

`agentdocs gems` writes each gem's bundle to a computed canonical path,
`<XDG data home>/yard-agentdocs/gems/<full name>`. Every reader in the lookup family
treats the existence of that directory as the answer to "is this gem documented" —
`BundleLocator` resolves a version, derives the directory, and confirms it is there,
with no validation step of its own.

Originally `GemBuilder` wrote straight into the canonical path and removed it only when
a build *returned* failure. A run killed partway — an expired agent command timeout, a
Ctrl-C, a SIGTERM — therefore left a partial tree that the next `--no-rebuild` run
counted as finished, and every later reader got silently incomplete documentation with
nothing to tell it apart from a complete bundle. (Issue #3.)

## Decision

Every observable state of a canonical bundle path is a complete bundle or nothing at
all. A gem is documented into a scratch directory under `.incomplete` in the same
output root and renamed to its canonical path only once the build has finished. The
same path carries `--rebuild`, so a failed rebuild no longer destroys the bundle it was
replacing.

Concurrency is deliberately not serialized. Two builders racing one gem each publish a
complete bundle and the last writer wins, so the only cost is duplicated work. A
publish that loses the race retries once, and the sweep of abandoned scratch
directories claims each candidate with a rename before deleting it, so those two
mechanisms preserve the property rather than relying on races being rare.

## Consequences

This contract has one writer and several dependents, which is why it is recorded here
rather than in any one class's documentation:

- **`GemBuilder`** owns the writing half: the scratch directory, the rename, and the
  age-based sweep of trees left behind.
- **`GemCleaner`** must never recognize a scratch directory as a bundle. The hidden
  dotted name is what guarantees that: `.incomplete` does not parse as
  `<name>-<version>`. Loosening `parse_bundle_name` would surface builds in progress
  as bundles and skew `--all-outdated` grouping.
- **`BundleLocator`, `Lookup`, and `BundlePath`** rely on existence implying
  completeness. If this contract is ever relaxed, they each need a validation step they
  do not have today.
- The scratch directory has to live **inside the output root**. Publishing is a rename,
  and a rename is only atomic within one filesystem; across one it fails with `EXDEV`
  and forces a copy, reintroducing the partially-visible state being designed out.
- Abandoned scratch trees are swept by **age, not liveness**. A killed build's scratch
  tree occupies disk for up to a day, which is bounded and invisible.
- **Not extended to `Builder`** (`agentdocs build`), whose output path is named by the
  user, may be on another filesystem, and may be under the user's own eye. The bug is
  about the gems root, where the path is computed rather than chosen and a reader has
  no way to judge what it finds.
- A future `agentdocs search` (issue #5) inherits this rather than reopening it.

## Considered options

- **Cleaning up from a signal handler.** Answers Ctrl-C and SIGTERM and nothing else —
  not SIGKILL, not a lost terminal, not a harness reaping a process group — and a
  handler that deletes a partial tree can itself be killed halfway through, which is
  the same bug one level down.
- **Staging in the system temporary directory.** `EXDEV`, per the consequence above.
- **Flat scratch names in the output root**, such as `.tmp-rbs-3.10.0-4321`.
  `GemCleaner.parse_bundle_name` reads that as gem `.tmp-rbs-3.10.0` at version `4321`.
- **Pid liveness for the sweep.** A pid says nothing about a build started on another
  machine sharing the same data home, and pids are reused.
- **Lock files**, for mutual exclusion or for sweep liveness. A lock adds a stale-lock
  failure mode and buys nothing that last-writer-wins does not already give.
