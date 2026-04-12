# ADR-0026: BTRFS as Recommended Default, ZFS as Optional

**Status**: Accepted
**Date**: 2026-04-12

## Context

When operators want snapshot-capable volumes (see [ADR-0025](0025-filesystem-driver-abstraction.md)), they need to choose between BTRFS and ZFS. Both are mature copy-on-write filesystems with snapshot and send/receive capabilities, but they differ significantly in availability and setup requirements.

Key forces:

- The target audience includes small teams and solo admins. Setup friction matters.
- BTRFS is included in the mainline Linux kernel and is the default filesystem on Fedora and openSUSE.
- ZFS requires OpenZFS installation (DKMS kernel modules or manual builds) and has licensing constraints that prevent kernel inclusion.
- Many operators have existing ZFS infrastructure and expertise.

## Decision

BTRFS is the recommended default for snapshot-capable volumes. ZFS is supported as an optional driver for operators with existing ZFS infrastructure.

The documentation and setup guides will recommend BTRFS first. ZFS documentation will assume the operator already has ZFS installed and configured.

## Consequences

### Positive

- BTRFS works out of the box on all major Linux distributions — no kernel modules to compile, no DKMS, no compatibility concerns with kernel updates.
- Lower barrier to entry for operators new to copy-on-write filesystems.
- ZFS remains available for operators who already use it and want to leverage their existing infrastructure.

### Negative

- BTRFS has historically had stability concerns (though modern BTRFS on Linux 5.x+ is considered stable for the operations Podmander uses: subvolumes, snapshots, send/receive).
- Recommending BTRFS over ZFS may be controversial among ZFS advocates. The recommendation is based on availability, not technical superiority.

### Neutral

- Both drivers have the same capability surface in Podmander (snapshot, send/receive, rollback). The driver abstraction (see [ADR-0025](0025-filesystem-driver-abstraction.md)) ensures the operator experience is identical.

## Alternatives Considered

### ZFS as recommended default

- Pros: More mature, better data integrity guarantees (checksumming, self-healing), richer feature set (compression, deduplication, quotas).
- Cons: Not in the mainline kernel. Requires OpenZFS installation, which involves DKMS or manual module builds. Kernel update compatibility is an ongoing concern. Setup friction is significantly higher.
- Why rejected: Installation complexity contradicts the "less than Kubernetes" philosophy. Operators who want ZFS likely already have it.

### Support only one filesystem

- Pros: Simpler — one driver to implement, test, and document.
- Cons: Either excludes operators with existing ZFS infrastructure (if BTRFS only) or raises the barrier to entry (if ZFS only).
- Why rejected: Both filesystems have legitimate user bases. The driver abstraction (see [ADR-0025](0025-filesystem-driver-abstraction.md)) makes supporting both manageable.

## References

- [ADR-0025](0025-filesystem-driver-abstraction.md) — Filesystem driver abstraction
- [ADR-0027](0027-snapshots-linked-to-versions.md) — Snapshots linked to service versions
