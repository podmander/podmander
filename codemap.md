# Repository Atlas: Podmander

## Project Responsibility

Podmander is a small-fleet container orchestration system for operators who need
more than single-host Compose and less than Kubernetes. It ships three Ada
deliverables: `podmander-controller`, `podmander-agent`, and `podctl`. The system
keeps the Controller authoritative for fleet state, reaches Nodes through their
Agents, and generates configuration for existing host tools instead of replacing
systemd, Podman, SQLite, ZeroMQ, or distribution packaging.

## System Entry Points

- `src/bin/podmander_controller.adb`: starts the Controller process, loads
  runtime config, opens Controller state, and runs the reconciliation loop.
- `src/bin/podmander_agent.adb`: starts the Agent process on a Node, loads its
  runtime config, registers with the Controller, and receives deployment work.
- `src/bin/podctl.adb`: starts the operator CLI command dispatcher.
- `podmander.gpr`: builds `podmander-controller` and `podmander-agent` from the
  production source tree.
- `podctl.gpr`: builds the `podctl` CLI from the CLI, protocol, and shared
  source subsets.
- `podmander_tests.gpr`: builds the AUnit test runner; tests are intentionally
  outside this codemap's core-source scope.
- `alire.toml`: declares the Ada package, project files, dependency pins, and
  Ada 2022/style-check settings.
- `mise.toml`: defines local build, test, formatting, RPM packaging, container,
  and CodeGraph tasks.
- `Containerfile.podmander`: builds the privileged Fedora/systemd/Podman test
  container used for local runtime integration work.

## Repository Directory Map

| Directory | Responsibility Summary | Detailed Map |
| --- | --- | --- |
| `src/` | Ada implementation of the Controller, Agent, CLI, protocol, database, config parser, and artifact generators. | [src/codemap.md](src/codemap.md) |
| `src/agent/` | Agent runtime for Node registration, heartbeat handling, Quadlet writes, Podman/systemd host commands, and Deployment_Result replies. | [src/agent/codemap.md](src/agent/codemap.md) |
| `src/controller/` | Controller state owner for registration, scheduling, Service Catalog persistence, Stack_Submission handling, and supervisor-driven deployment. | [src/controller/codemap.md](src/controller/codemap.md) |
| `src/cli/` | `podctl` command parsing, connection config, Stack_Submission sending, and user-facing result formatting. | [src/cli/codemap.md](src/cli/codemap.md) |
| `src/protocol/` | Shared JSON-over-CZMQ message contract and dispatch registry for CLI, Controller, and Agent traffic. | [src/protocol/codemap.md](src/protocol/codemap.md) |
| `src/config/` | TOML parsing and validation into Podmander's current Abstract Service Definition. | [src/config/codemap.md](src/config/codemap.md) |
| `src/generators/` | Derived artifact generation, currently rendering Abstract Service Definitions into Podman Quadlet content. | [src/generators/codemap.md](src/generators/codemap.md) |
| `src/shared/` | Cross-cutting helpers for logging, command-line option lookup, runtime config, and Join Token enrollment. | [src/shared/codemap.md](src/shared/codemap.md) |
| `packaging/` | Production installation assets for config files, systemd units, and Fedora RPM metadata. | [packaging/codemap.md](packaging/codemap.md) |
| `packaging/config/` | Packaged controller TOML defaults installed under `/etc/podmander`. | [packaging/config/codemap.md](packaging/config/codemap.md) |
| `packaging/systemd/` | systemd unit files for host-managed Controller and Agent daemons. | [packaging/systemd/codemap.md](packaging/systemd/codemap.md) |
| `packaging/rpm/` | Fedora RPM spec and local build helper for source/binary package creation. | [packaging/rpm/codemap.md](packaging/rpm/codemap.md) |

## Flow

The main operator flow begins with `podctl deploy`: the CLI sends raw Stack TOML
as a `Stack_Submission` to the Controller. The Controller authorizes the
enrollment secret, parses the TOML into an Abstract Service Definition, records a
Service and Service Version, updates the Service Catalog, and returns only the
submission acceptance result. The Supervisor Loop later reconciles Service
Catalog drift by rendering Quadlet content and sending a `Deployment_Command` to
the Agent for the assigned Node. The Agent writes the Quadlet, invokes host tools
through systemd/Podman boundaries, and returns a `Deployment_Result` that updates
the Service Catalog.

Agent enrollment is a parallel control-plane flow. A Join Token carries the
Controller CURVE public key plus enrollment secret. Agents parse the token,
register over the ZeroMQ control channel, send heartbeats, and let the Controller
track Node/Agent liveness before deployment work is delivered.

## Integration

Podmander integrates with external systems through narrow boundaries:

- SQLite stores Controller-owned fleet state.
- ZeroMQ/CZMQ carries encrypted control-plane messages.
- Podman and systemd execute workloads from generated Quadlets.
- Alire/GPR project files build the Ada deliverables.
- systemd and RPM packaging install and supervise the production daemons.

For deep work, start with this atlas, then open the codemap for the relevant
source or packaging folder before reading individual packages.
