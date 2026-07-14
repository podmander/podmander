# src/agent/

## Responsibility

`src/agent/` implements the Podmander Agent that runs on each Node. It is the
local executor reached by the Controller over the protocol layer: it registers
with the Controller, maintains heartbeats, receives `Deployment_Command`
messages, writes received Quadlet content to the Node filesystem, invokes the
host tools needed to activate workloads, queries Podman for status, and returns
`Deployment_Result` or status responses. The Agent is intentionally light on
state; its durable local effect is the Quadlet file written under the user
systemd container directory.

## Design

- `Podmander.Agent` owns the long-lived `Agent_Instance`: runtime config,
  connection state, cached join-token data, CZMQ certificate, and CZMQ DEALER
  socket. `Initialize` parses the join token once, `Run` repeatedly executes
  connection cycles, and `Stop` flips the run flag.
- `Podmander.Agent.Connection` is the connection state machine. One cycle closes
  previous CZMQ resources, creates a fresh CURVE certificate and DEALER socket,
  enrolls with the Controller, and then enters a heartbeat-bounded receive loop.
- `Podmander.Agent.Message_Handlers.Agent_Handler` is the concrete protocol
  dispatcher for Controller-to-Agent messages. It accepts only commands relevant
  to an Agent and logs warnings for message kinds that should flow the other
  way.
- `Podmander.Agent.Podman` is the host-side capability facade. It translates
  protocol-level requests into Quadlet file writes, `systemctl --user` steps,
  and `podman ps` status checks.
- `Podmander.Agent.Atomic_File` isolates the safe-write pattern for Quadlets:
  write `Path & ".tmp"`, then rename over the target so a failed write does not
  leave a partial Quadlet at the final path.
- `Podmander.Agent.Host_Command` wraps Spoon process execution and captures
  stdout/stderr into a discriminated `Command_Result`; `Result_Mapping` folds
  process outcomes into the protocol `Result_Code` vocabulary used by
  `Deployment_Result` and status responses.
- `Podmander.Agent.Runtime_Config` loads `/etc/podmander/agent.toml` plus CLI
  overrides into `Agent_Config` and log level, validating required token and
  heartbeat interval inputs.

## Flow

1. Startup code loads runtime config through `Runtime_Config.Load`, then
   initializes an `Agent_Instance` with Controller address, Agent name, join
   token, heartbeat interval, registration timeout, and reconnect backoff.
2. `Agent.Run` loops while the Agent is running and no process interrupt has
   been signaled. Each iteration calls `Connection.Run_Cycle`.
3. A connection cycle rebuilds CZMQ resources, applies the Agent certificate,
   configures the Controller public key from the join token, sets the socket
   identity to the Agent name, connects to the Controller, and sends a
   registration request containing the Agent name and enrollment secret.
4. During enrollment, the Agent waits for a registration response. Timeout uses
   exponential backoff and returns to the outer run loop; malformed or
   unexpected responses disconnect the cycle; a valid response stores the
   Controller-provided connection id and marks the Agent connected.
5. While connected, the Agent sends a heartbeat carrying its connection id,
   receives protocol messages until the next heartbeat deadline, decodes each
   message, and dispatches it to `Agent_Handler`.
6. For a `Deployment_Command`, the handler extracts the service name and
   Quadlet payload, calls `Podman.Install_Quadlet`, copies the command's
   `catalog_id` into the returned `Deployment_Result`, encodes the result, and
   sends it back on the Agent socket.
7. `Install_Quadlet` creates `~/.config/containers/systemd`, atomically writes
   `<service>.container`, runs `systemctl --user daemon-reload`, then runs
   `systemctl --user start <service>.service`. Any failed host command is mapped
   to a protocol result code; exceptions return an internal-error
   `Deployment_Result`.
8. For a status query, the handler calls `Podman.List_Containers`, which runs
   `podman ps --format "{{.Names}} {{.Status}}"`, maps the host-command result,
   and returns container output or error detail in a status response.

## Integration

- Depends on `Podmander.Messages` and concrete message packages for protocol
  encoding/decoding and dispatch of `Deployment_Command`, `Deployment_Result`,
  registration, heartbeat, and status messages.
- Depends on `Podmander.Enrollment` to parse the join token into Controller
  CURVE public key and enrollment secret before connecting.
- Depends on CZMQ certificates, sockets, messages, and signal handling for the
  encrypted Controller-Agent transport.
- Depends on `Podmander.Types.Connection_State` for the Agent state machine and
  on `Podmander.Logging` for operational logs.
- Depends on TOML and shared runtime-config helpers for Agent configuration.
- Integrates with the Node operating environment through `HOME`, Quadlet files
  under `~/.config/containers/systemd`, `systemctl --user`, and the Podman CLI.
- Consumed by the Agent executable/startup layer, while the Controller consumes
  its registration, heartbeat, `Deployment_Result`, and status response traffic.
