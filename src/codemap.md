# src/

## Responsibility

`src/` contains the Ada implementation for the Podmander deliverables:
`podmander-controller`, `podmander-agent`, and `podctl`. It owns the runtime
paths between the operator-facing CLI, the Controller that manages fleet state,
and the Agent running on each Node.

Root-level packages provide shared infrastructure used across those
deliverables:

- `podmander-control_channel.*` wraps the ZeroMQ/CZMQ control channel used by
  CLI, Controller, and Agent message exchange.
- `podmander-database.*`, `podmander-database-migrations.*`, and
  `podmander-database-time_utils.*` own the Controller's SQLite state database,
  migrations, and time conversion helpers.

Major subdirectories divide the application by responsibility:

- `src/bin/` defines the executable entry points for `podctl`,
  `podmander-agent`, and `podmander-controller`.
- `src/cli/` implements `podctl` command parsing and operator commands.
- `src/controller/` implements Controller state management, enrollment,
  scheduling, Service Catalog handling, and the Supervisor Loop.
- `src/agent/` implements Agent connection management, message handling,
  Quadlet writes, Podman/systemd host commands, and runtime configuration.
- `src/protocol/` defines shared protocol types and JSON serialization for
  Registration, Status, Stack_Submission, Deployment_Command, and
  Deployment_Result messages.
- `src/config/` parses operator Stack TOML into Abstract Service Definitions
  consumed by the Controller pipeline.
- `src/generators/` renders derived execution artifacts, currently Podman
  Quadlets, from service configuration.
- `src/shared/` contains cross-cutting helpers for logging, command-line
  argument lookup, enrollment tokens, and runtime configuration loading.

## Design

The source tree keeps the Podmander deliverables thin at their executable
boundaries. `src/bin/podctl.adb` registers built-in CLI commands and dispatches
them. `src/bin/podmander_agent.adb` and `src/bin/podmander_controller.adb` load
runtime configuration, apply command-line overrides, set logging level, and then
instantiate the corresponding Agent or Controller object.

Domain logic lives behind package boundaries rather than in the entry points:

- The Controller is the only writer to fleet state. It stores Services, Service
  Versions, Service Catalog Entries, node/agent records, and enrollment state in
  SQLite through the root database packages and controller repositories.
- Agents are protocol-layer executors for Nodes. They remain stateless beyond
  local Quadlet files and runtime process state, receiving Deployment_Commands
  and returning Deployment_Results.
- Protocol messages are modeled explicitly in `src/protocol/`, following the
  domain naming convention where request/response roles are part of the message
  name.
- Generated artifacts are separated from domain parsing: the config parser
  produces the Abstract Service Definition, while generator packages render
  Quadlets as derived artifacts.

## Flow

The primary operator flow starts in `podctl`:

1. `src/bin/podctl.adb` initializes the CLI command registry from `src/cli/`.
2. The `deploy` command reads a Stack TOML file and sends a Stack_Submission to
   the Controller over the control channel.
3. Controller message handlers authorize the submission with the enrollment
   secret, parse the Stack into an Abstract Service Definition, register the
   Service and Service Version, and update the Service Catalog with the desired
   target version.
4. The Supervisor Loop compares current and target Service Catalog state. When
   drift exists, it generates Quadlet content and sends a Deployment_Command to
   the Agent assigned to the target Node.
5. The Agent receives the Deployment_Command, writes Quadlets atomically, runs
   host commands against systemd/Podman boundaries, and replies with a
   Deployment_Result.
6. The Controller consumes Deployment_Results and updates the Service Catalog's
   current version or failure flag.

The enrollment/status flow also crosses the same layers: Agents use Join Tokens
from the Controller, register over the control channel, send heartbeats/status,
and are tracked by Controller agent repository and liveness packages.

## Integration

`src/` integrates generated configuration with external tools rather than
reimplementing their responsibilities:

- SQLite stores Controller-owned fleet state through the database and migration
  packages.
- ZeroMQ/CZMQ carries CLI-to-Controller and Controller-to-Agent protocol
  messages through the control channel.
- Podman and systemd execute workloads from Quadlet files written by Agents.
- TOML Stack input enters through `src/config/` and becomes an Abstract Service
  Definition before registration and Quadlet generation.

The root source packages connect the subtrees: protocol packages define the
wire-level contracts, shared packages handle common runtime concerns, the
database packages persist Controller state, and the bin entry points assemble
those pieces into the three installed Podmander deliverables.
