# Open Questions

Research questions that have surfaced during design but have no settled answer yet.
Each entry names the question, explains why it matters, and lists known options or constraints.

---

## TLS Certificate Distribution Across Multiple Ingress Nodes

**Context:** ADR-0020 and the [ingress spec](spec/ingress.md) currently assume a single
ingress node running Caddy. Caddy handles Let's Encrypt certificate issuance automatically.
Multi-node ingress (for availability or load distribution) is listed as a future item.

**Question:** When Podmander runs Caddy on more than one ingress node, how are TLS
certificates kept consistent across those nodes?

**Why it matters:** Let's Encrypt rate-limits issuance per domain. If each ingress node
requests its own certificate independently, the cluster will exhaust the rate limit and
nodes may serve different certificates during a transition window, causing validation
errors for clients.

**Known options:**

| Option | Summary | Trade-offs |
|--------|---------|------------|
| Shared storage mount | All ingress nodes read/write certificates from a shared NFS/CIFS/distributed volume | Adds infrastructure dependency; shared storage becomes a new failure domain |
| Designate primary | One node obtains certificates; others receive copies via rsync/SCP on a schedule | Simple, but certificate sync lag is a risk; primary node is a soft SPOF for renewals |
| Caddy clustering (experimental) | Caddy has experimental cluster certificate sharing via a shared `storage` backend (S3, Redis, Consul) | Caddy's clustering story is still maturing; requires an additional shared service |
| External cert manager | A tool like `cert-manager` (Kubernetes-native) or `acme.sh` manages certs centrally and distributes them | Proven at scale, but introduces an independent daemon and operational overhead outside Podmander's model |
| DNS-01 challenge + wildcard cert | Issue a single wildcard certificate via DNS-01 challenge; distribute that one cert | Requires DNS provider API access; wildcards don't cover sub-sub-domains; automates renewal less easily |

**Open sub-questions:**
- Does Podmander's agent-mediated secret delivery (ADR-0022) give us a natural distribution
  channel for certificates, or is the renewal lifecycle too different from application secrets?
- Should Podmander own certificate distribution, or delegate it entirely to the operator
  (document the requirement, provide a hook point)?

**References:**
- [ADR-0020 — Caddy for ingress](adr/0020-caddy-for-ingress.md)
- [ADR-0022 — Agent-mediated secret delivery](adr/0022-agent-mediated-secret-delivery.md)
- [Ingress spec — Open Items](spec/ingress.md#open-items)
- Caddy `storage` module docs: https://caddyserver.com/docs/caddyfile/options#storage

---

## Ada Logging Library Landscape

**Context:** Podmander currently ships a minimal `Podmander.Logging` package that supports
log levels, TTY-based format detection (`isatty`), and syslog priority prefixes for journald.
This covers immediate needs but has known gaps (see below).

**Question:** Should Podmander adopt an existing Ada logging library instead of growing its own?

**Why it matters:** Custom logging tends to accumulate features over time (structured output,
JSON format, `JOURNAL_STREAM` detection, configurable handlers, log rotation). Before we go
down that path, we should evaluate what's already available in the Ada ecosystem.

**Known gaps in current implementation:**

| Gap | Impact |
|-----|--------|
| `isatty`-only detection | Piped output (not journald) gets syslog `<N>` prefixes instead of human-readable format |
| No `JOURNAL_STREAM` support | Cannot distinguish "piped to journald" from "piped elsewhere" |
| No explicit format override | No `--log-format=text\|syslog` flag to bypass detection |
| No structured/JSON output | Future monitoring pipelines may need machine-readable logs |

**Action:** Research existing Ada logging libraries (e.g., on AdaForge, GitHub, or Alire crates)
for feature coverage, license compatibility, and maintenance status before extending
`Podmander.Logging` further.

**References:**
- Issue #5 — Logging facility implementation
