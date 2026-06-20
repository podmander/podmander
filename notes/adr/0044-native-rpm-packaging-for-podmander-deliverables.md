# ADR-0044: Native RPM packaging for Podmander deliverables

**Date**: 2026-06-20

## Context

Podmander now needs a packaging and deployment strategy for its own shipped
artifacts: `podmander-controller`, `podmander-agent`, and `podctl`. These are
the **Podmander Deliverables**; they are distinct from user workload images and
from Podmander-managed Infrastructure Components such as Caddy, CoreDNS, and
Restic.

The obvious first idea is to ship the deliverables as container images, because
Podmander's domain is Podman container orchestration. That fit is superficial.
The agent is a privileged host integrator: it manages systemd units, writes
Quadlet files, queries Podman, and will manage host-level infrastructure such as
WireGuard, ingress, DNS, storage, and backups. Running the agent in a container
would require privileged containers, host filesystem mounts, and host systemd or
Podman access. That adds indirection without a meaningful isolation benefit.

The controller and agent are long-running host services. The CLI is an operator
tool. Packaging must make those roles explicit without guessing which role a host
should take.

## Decision

We will package Podmander's deliverables as a native, inert Fedora RPM named
`podmander`.

The single RPM will install these executable artifacts:

- `podmander-controller`
- `podmander-agent`
- `podctl`

The daemon executable names are the actual build artifact names, not install-time
aliases for `pod_controller` and `pod_agent`. Implementation of the executable
rename is tracked separately in #181.

The RPM will install both daemon systemd units on every host, disabled by
default:

- `podmander-controller.service`
- `podmander-agent.service`

Installing the package does not enable, start, or infer any host role. Operators
make the role explicit by creating the relevant configuration and enabling the
corresponding unit. The units include an `[Install]` section with
`WantedBy=multi-user.target` so explicit `systemctl enable --now ...` activation
works normally; the RPM simply does not enable or start them.

Daemon configuration is role-specific:

- `/etc/podmander/controller.toml`
- `/etc/podmander/agent.toml`

The package owns `/etc/podmander/` and installs a real default controller config
as an RPM `%config(noreplace)` file. The controller can safely have useful
defaults: bind on all interfaces at the standard control-plane port, store its
SQLite database under `/var/lib/podmander/controller/`, and mint enrollment
material on first start.

The package does not install a real agent config. A valid agent config requires
deployment-specific values such as the controller endpoint and join token, so the
agent config is installed only as documentation/example material. An agent
started without its required config should fail fast with a clear error.

Daemon configuration loading follows ordinary precedence: hardcoded defaults,
then config file values, then CLI flags. Environment variable overrides are not
part of the initial configuration surface.

Persistent state is role-specific:

- `/var/lib/podmander/controller/` for controller state, including the SQLite
  database and controller identity material when file-backed storage is added.
- `/var/lib/podmander/agent/` for agent-local durable state if needed.
- `/run/podmander/` for volatile runtime files.

The systemd units should create role-specific persistent state directories with
`StateDirectory=` rather than RPM install scriptlets. Package installation remains
inert; explicit service activation prepares the relevant state directory.
They should also create role-specific volatile runtime directories with
`RuntimeDirectory=` so one daemon stopping cannot clean up another daemon's
runtime state.

Logs go to the systemd journal by default; the package does not create a
`/var/log/podmander` tree.

The daemon units run as `root` initially. This follows
[ADR-0012](0012-rootless-containers-rootful-agent.md): the agent needs root for
host management, while workload containers still run rootless by default. We will
use systemd hardening where it does not block required host integration. The
units will not use `DynamicUser=yes`; the daemons need stable host access and
predictable permissions for configuration, state, systemd, Quadlet, and Podman
integration.

The base RPM declares hard dependencies only for Podmander's core runtime needs:
systemd, Podman, ZeroMQ/CZMQ runtime libraries, SQLite runtime libraries, and any
required Ada runtime libraries. Role-specific auxiliary tools such as Caddy,
CoreDNS, Restic, ZFS/Btrfs tools, and WireGuard tooling are not base package
dependencies unless a core daemon path requires them unconditionally.

`podctl` keeps its per-user configuration default:

- `~/.config/podmander/podctl.toml`

Fedora RPM is the first-class packaging target. Debian packages and
RHEL-compatible distributions can follow later after the package layout and
activation model are proven.

CI is not a prerequisite for the first packaged releases. The initial release
path may be a local `mise` task that builds RPM artifacts, followed by a manual
upload to a Forgejo release. Automated CI packaging can replace that manual step
later without changing the package model.

Initial node installation is manual/operator-driven. Future bootstrap automation
may consume this RPM, but packaging does not depend on solving bootstrap.

## Consequences

### Positive

- Podmander is installed in the same layer where its daemons operate: the host
  systemd/Podman environment.
- Package installation is safe and inert; a host does not become a controller or
  worker until an operator explicitly enables a unit. The controller can start
  from packaged defaults, while the agent still requires operator-created
  enrollment config.
- One package keeps early distribution simple while separate config, state, and
  unit names keep the controller and agent roles clear.
- The public artifact names match what operators see in systemd, logs, and
  packaging.
- The dependency boundary stays narrow: installing Podmander does not pull every
  possible infrastructure role tool onto every host.

### Negative

- A single RPM installs daemon units that may never be used on a given host.
- Operators must perform explicit setup after installation; the first package is
  not a one-command bootstrap experience.
- Fedora-first packaging leaves Debian and RHEL-family compatibility work for
  later.
- Manual package builds and release uploads put more process burden on the
  maintainer until CI packaging exists.
- Running the controller as root is likely broader privilege than it ultimately
  needs; reducing controller privilege remains a future hardening opportunity.

### Neutral

- Container images remain useful for local integration tests, demos, or
  development environments, but they are not the production packaging unit for
  Podmander deliverables.
- SSH-based node bootstrap remains a possible future feature, but
  [ADR-0032](0032-ssh-based-node-bootstrap.md) is abandoned and does not constrain
  this packaging decision.

## Alternatives Considered

### Container images for controller and agent

- Pros: Superficially matches Podmander's container-orchestration domain; easy to
  publish in OCI registries.
- Cons: The agent needs privileged host integration. A container with enough
  access to manage systemd, Quadlets, Podman, and host networking is effectively a
  privileged host process with extra indirection.
- Why rejected: Native installation is more honest about the daemon boundary and
  avoids a brittle privileged-container deployment model.

### Separate RPMs per deliverable

- Pros: Hosts install only the binaries and units they need; dependencies can be
  role-specific from the start.
- Cons: More packaging surface before roles and dependency boundaries have proven
  themselves; more choices for operators during early adoption.
- Why rejected: A single inert package is simpler for the first distribution
  path. Explicit config and disabled units avoid role confusion without splitting
  packages immediately.

### Auto-enable units or install default active agent config

- Pros: Faster first-start path after package installation.
- Cons: The package would have to guess deployment-specific enrollment values and
  would risk starting a privileged agent with placeholder state.
- Why rejected: Role selection must be explicit. Installation should lay down
  artifacts, not make operational decisions. A controller default config is
  acceptable because it does not require fleet-specific secrets from the
  operator; an agent default config is not.

### Make SSH bootstrap the first installation path

- Pros: Better future operator experience for adding nodes.
- Cons: Requires solving security, idempotence, recovery, distro detection, and
  privilege-escalation concerns before packaging can ship.
- Why rejected: Bootstrap is a product feature layered on top of packaging. The
  RPM should be useful manually and by future automation.

### Debian or RHEL-compatible packages first

- Pros: Broader initial platform coverage.
- Cons: Adds compatibility work around dependency availability, Podman/Quadlet
  versions, systemd behavior, and Ada packaging before the package model is
  validated.
- Why rejected: Fedora aligns best with the current development and runtime
  assumptions. Other distributions can follow from a proven layout.

## References

- [ADR-0001](0001-controller-agent-topology.md) — Controller-agent topology
- [ADR-0011](0011-podman-quadlet-for-containers.md) — Podman with Quadlet for container execution
- [ADR-0012](0012-rootless-containers-rootful-agent.md) — Rootless containers with rootful agent
- [ADR-0030](0030-decentralized-journal-logging.md) — Decentralized logging via systemd journal
- [ADR-0032](0032-ssh-based-node-bootstrap.md) — Abandoned SSH bootstrap decision
- Issue #180 — Define Podmander deliverable packaging strategy
- Issue #181 — Rename daemon executables to explicit Podmander names
- Issue #182 — Add local RPM packaging task
- Issue #183 — Add daemon config file loading
