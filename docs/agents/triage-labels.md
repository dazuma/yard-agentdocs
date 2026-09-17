# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the actual label strings used in this repo's issue tracker.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for agent-assisted implementation |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the agent-ready triage label"), use the corresponding label string from this table. Skills sometimes call `ready-for-agent` "AFK-ready"; read that as the role, not as a claim that the work is unattended — see the note below.

**On `ready-for-agent`:** it means the issue is specified well enough for an
agent to do the implementation work *with* a human, not that the work is
unattended. Several of this repo's workflows are explicitly human-gated — the
coverage workflow in `CLAUDE.md`, for instance, requires human review of proposed
`examples/` changes before any implementation — so an "AFK-ready" reading of
this label would promise something the process does not deliver.

Edit the right-hand column to match whatever vocabulary you actually use.
