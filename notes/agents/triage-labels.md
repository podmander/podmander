# Triage Labels

Issue **category** uses organization-level `Kind/` labels, shared across all
organization repositories:

| Work type | Label in our tracker |
| --------- | -------------------- |
| Bug | `Kind/Bug` |
| Documentation | `Kind/Documentation` |
| Refactor or existing infrastructure work | `Kind/Enhancement` |
| New feature or infrastructure capability | `Kind/Feature` |
| Security | `Kind/Security` |
| Testing | `Kind/Testing` |

Epics are top-level tracking issues with a checklist breakdown of work items;
they are not represented by a label.

Issue **triage state** uses organization-level `Status/` labels. The skills
speak in terms of canonical triage roles; this table maps those roles to the
label strings used in this tracker.

| Label used in skills | Label in our tracker | Meaning |
| -------------------- | -------------------- | ------- |
| `needs-triage` | `Status/Review needed` | Maintainer needs to evaluate this issue |
| `needs-info` | `Status/Need More Info` | Waiting on reporter for more information |
| `ready-for-agent` | `Status/Ready for agent` | Fully specified, ready for an AFK agent |
| `ready-for-human` | `Status/Ready for human` | Requires human implementation |
| `wontfix` | `Reviewed/Won't Fix` | Will not be actioned |
| _(repo-specific)_ | `Status/Blocked` | Evaluated and valid, but blocked on an unbuilt prerequisite |

When a skill mentions a role (for example, "apply the AFK-ready triage label"),
use the corresponding label string from this table.

`Status/Blocked` has no skill role. Apply it to issues that are fully evaluated
but cannot proceed until a prerequisite issue lands, and cross-reference the
blocker.
