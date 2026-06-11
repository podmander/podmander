# Triage Labels

Issue **category** uses organization-level labels (no prefix), shared across all org repos: `bug`, `documentation`, `epic`, `feature`, `infra`, `refactor`, `test`.

Issue **triage state** uses repo-level `triage/`-prefixed labels. The skills speak in terms of canonical triage roles; this table maps those roles to the label strings used in this repo's tracker.

| Label used in skills | Label in our tracker     | Meaning                                                     |
| -------------------- | ------------------------ | ----------------------------------------------------------- |
| `needs-triage`       | `triage/needs-triage`    | Maintainer needs to evaluate this issue                     |
| `needs-info`         | `triage/needs-info`      | Waiting on reporter for more information                    |
| `ready-for-agent`    | `triage/ready-for-agent` | Fully specified, ready for an AFK agent                     |
| `ready-for-human`    | `triage/ready-for-human` | Requires human implementation                               |
| `wontfix`            | `wontfix`                | Will not be actioned (organization-level label)             |
| _(repo-specific)_    | `triage/blocked`         | Evaluated and valid, but blocked on an unbuilt prerequisite |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from this table. Note that `wontfix` is an organization-level label (no `triage/` prefix); the rest are repo-level.

`triage/blocked` has no skill role — apply it to issues that are fully evaluated but cannot proceed until a prerequisite issue lands, and cross-reference the blocker.
