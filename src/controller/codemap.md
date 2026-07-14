# src/controller/

## Responsibility

`src/controller/` is the Controller-side production implementation for a
Podmander Fleet. It owns the SQLite-backed fleet state, coordinates Nodes
through their Agents, accepts operator Stack_Submission messages, turns parsed
service definitions into immutable Service Version records, records deployment
intent in the Service Catalog, schedules unscheduled Service Catalog entries to
Nodes, and drives asynchronous deployment through Deployment_Command and
Deployment_Result protocol messages.

The Controller is the only writer to controller state. Agents execute work on
Nodes, but placement targets Nodes: Agent state is used to resolve whether a
Deployment_Command can be delivered to the assigned Node.

## Design

- `Podmander.Controller` is the root package. It defines Controller-wide domain
  types (`Service_Id_Type`, `Service_Version_Type`, `Service_Version`,
  `Service_Catalog_Entry`, `Catalog_Entry_State`, `Node_Option`) and the
  `Controller_Instance` aggregate that holds configuration, database handle,
  CURVE certificate, control channel, and run flag.
- Startup is centralized in `Make_Listening_Controller`: choose the state DB
  path, open the database, recover Agent liveness and stale Service Catalog
  entries, bootstrap the controller certificate and enrollment secret, then bind
  the ROUTER control channel.
- Message dispatch uses the protocol visitor/handler pattern. The controller
  poll loop receives a protocol message, constructs a `Controller_Handler`, and
  dispatches the message to the concrete `Handle_*` override in
  `Message_Handlers`.
- Persistence is organized as repositories around domain aggregates:
  `Agent.Repository`, `Node.Repository`, `Service.Repository`, and
  `Service_Catalog.Repository`. Repositories expose domain operations and hide
  SQL/serialization details from orchestration code.
- `Registrar` is the registration stage for submitted services: it creates or
  loads the Service row, computes the next Service Version number, and persists
  the immutable Service Version snapshot.
- `Scheduler` owns persistence of placement decisions into the Service Catalog.
  It delegates only Node selection to a pluggable `Strategies.Strategy_Type`.
  The MVP strategy is `First_Available`, which selects the first Registered
  Agent's Node.
- `Supervisor` is the reconciliation component. Each tick schedules entries
  with no assigned Node, then deploys Pending entries that have an assigned Node
  and a Registered Agent.
- `Enrollment_Authority` isolates controller identity and authorization:
  certificate bootstrap/public key, join-token generation, registration secret
  bootstrap, and shared-secret checks for Agent registration and
  Stack_Submission authorization.
- `Agent.Liveness` maintains Agent state from heartbeat recency. Startup resets
  non-Lost Agents to Unresponsive; regular checks move stale Agents from
  Registered to Unresponsive and then Lost.

## Flow

1. Controller lifecycle:
   - `Make_Listening_Controller` opens the controller DB, calls
     `Agent.Liveness.Recover` and `Supervisor.Recover`, bootstraps enrollment
     credentials, and starts the control channel listener.
   - `Run` loops while the Controller is running: receive and dispatch one
     message, check Agent liveness timeouts, then run `Supervisor.Tick`.
2. Agent enrollment and liveness:
   - A Registration_Request is authorized by `Enrollment_Authority.Authorize`.
   - `Node.Repository.Create_Or_Get` ensures the Node identity exists.
   - `Agent.Repository.Register` persists the connection-scoped Agent as
     Registered; duplicate registration updates last-seen and state instead.
   - The Controller replies with Registration_Response and immediately sends a
     Status_Query.
   - Heartbeat updates `last_seen`; if the Agent was not Registered, it is
     restored to Registered and any In_Progress Service Catalog entries for its
     Node are reset to Pending so Deployment_Command messages can be retried.
3. Stack_Submission pipeline:
   - `Message_Handlers.Handle_Stack_Submission` authorizes the submitted
     enrollment secret and calls `Stack_Submission.Submit` with raw TOML.
   - `Stack_Submission.Submit` parses TOML into an ASD, calls `Registrar` to
     create the Service and Service Version, then calls `Scheduler.Schedule` with
     the First_Available strategy.
   - `Scheduler.Schedule` selects a Node option, updates an existing Service
     Catalog entry to the new target version and Pending state, or creates a new
     entry with optional assigned Node.
   - The caller receives Stack_Submission_Result for acceptance/failure only;
     actual deployment is asynchronous.
4. Reconciliation and deployment:
   - `Supervisor.Tick` first schedules unscheduled Service Catalog entries using
     First_Available.
   - It then loads Pending entries. For each assigned entry, it finds a
     Registered Agent for the assigned Node, loads the target Service Version and
     Service name, renders a Quadlet, sends Deployment_Command through the
     control channel, and marks the entry In_Progress.
   - Deployment_Result with a real `catalog_id` updates the Service Catalog:
     success sets `current_version` to the target and state Deployed; failure
     sets state Failed. Legacy results without a catalog id are logged only.
5. Recovery behavior:
   - Controller startup resets all In_Progress Service Catalog entries to
     Pending, avoiding permanently stuck deployments after a crash.
   - Agent reconnect resets that Node's In_Progress entries to Pending, avoiding
     lost Deployment_Command messages while the Agent was disconnected.

## Integration

- Depends on `Podmander.Database` for the controller SQLite state database and
  on repository packages in this folder for all Controller-owned state changes.
- Depends on `Podmander.Control_Channel` for ZeroMQ/CURVE message transport.
  The Controller receives Registration_Request, Heartbeat, Stack_Submission,
  Status_Response, and Deployment_Result messages, and sends
  Registration_Response, Status_Query, Stack_Submission_Result, and
  Deployment_Command messages.
- Depends on `Podmander.Config.Parser` and `Podmander.Config.Service_Definition`
  for authoritative parsing of Stack_Submission TOML into ASDs.
- Depends on `Podmander.Generators.Quadlet` to render the Service Version into
  the Quadlet payload carried by Deployment_Command.
- Depends on `Podmander.Enrollment` and `CZMQ.Certificates` through
  `Enrollment_Authority` for join-token material, CURVE public key exposure, and
  enrollment secret verification.
- Consumed by the controller executable/CLI entrypoint outside this directory,
  which constructs a `Controller_Config`, calls `Make_Listening_Controller`, and
  runs the Controller loop.
