# Podmander

A container orchestration system for small multi-node deployments. Generates configuration for specialized tools (systemd, Podman, Caddy, Restic) rather than reimplementing their functionality.

## Language

**Service**:
A named, versioned deployable unit (e.g., "myapp"). The canonical identity for a workload in the system.
_Avoid_: Application, workload, container

**Service Version**:
An immutable snapshot of a service's Abstract Service Definition at a point in time. Identified by (service, version number). Monotonically increasing; rollback creates a new version.
_Avoid_: Deployment, release, config version

**Abstract Service Definition (ASD)**:
The structured representation of a service's configuration — image, environment variables, ports, volumes. The ASD is the source of truth; the Quadlet is derived from it.
_Avoid_: Service config, service definition (ambiguous with Service_Definition the parser type)

**Service Catalog**:
The single source of truth for deployment intent and status. Each entry maps a service to a node with a current version, target version, and failure flag. Replaces separate desired-state and actual-state tables.
_Avoid_: State table, deployment table

**Service Catalog Entry**:
A row in the Service Catalog: (service, node, current_version, target_version, failed). current_version = 0 means "not deployed." node_id = NULL means "not yet scheduled."
_Avoid_: Catalog row, state entry

**catalog_id**:
An opaque correlation token identifying a Service Catalog entry. Carried in Deploy_Command and echoed in Deploy_Result so the controller can correlate results without relying on (service_name, node_id) lookups.
_Avoid_: Deployment ID, request ID

**Registrar**:
Pipeline object that creates a Service row (if new) and a Service Version row from a parsed ASD.
_Avoid_: Inserter, persister

**Scheduler**:
Pipeline object that creates or updates a Service Catalog entry, assigning a node. For MVP, always assigns the single connected node or leaves node_id NULL if no agent is connected.
_Avoid_: Planner, placement engine

**Supervisor**:
The continuous reconciliation loop. Two jobs per iteration: (1) schedule any catalog entries with node_id = NULL, (2) deploy any entries where current_version ≠ target_version and failed = 0.
_Avoid_: Controller loop, reconciler

**Quadlet**:
A systemd/Podman unit file generated from an ASD. The concrete deployment artifact sent to the agent.
_Avoid_: Unit file, service file (ambiguous with Service)

**Agent**:
A process running on a managed node that receives Deploy_Commands, applies Quadlets, and reports Deploy_Results back to the Controller.
_Avoid_: Node process, worker

**Controller**:
The central process that manages the Service Catalog, runs the Supervisor loop, and communicates with Agents.
_Avoid_: Server, master

**Deploy_Command**:
A message from Controller to Agent carrying a catalog_id, service name, and Quadlet content. Instructs the agent to deploy or update a service.
_Avoid_: Deploy request, deployment message

**Deploy_Result**:
A message from Agent to Controller carrying a catalog_id, service name, and success/failure status. Confirms whether a deployment landed.
_Avoid_: Deploy response, deployment result

## Relationships

- A **Service** has zero or more **Service Versions** (1:N)
- A **Service** has zero or more **Service Catalog Entries** (1:N, one per node)
- A **Service Catalog Entry** references one **Service Version** as its target (N:1)
- A **Service Catalog Entry** references one **Service Version** as its current version (N:1, or 0 = not deployed)
- A **Service Catalog Entry** references one **Agent** (N:1, or NULL = not scheduled)
- The **Registrar** consumes an ASD and produces a **Service** row and a **Service Version** row
- The **Scheduler** consumes a **Service Version** and produces or updates a **Service Catalog Entry**
- The **Supervisor** reads **Service Catalog Entries** and produces **Deploy_Commands**
- An **Agent** receives a **Deploy_Command** and produces a **Deploy_Result**
- The Controller processes a **Deploy_Result** and updates a **Service Catalog Entry**

## Example dialogue

> **Dev:** "When the operator deploys a new TOML, what happens?"
> **Domain expert:** "The Parser produces an ASD. The Registrar creates a Service Version. The Scheduler creates a Service Catalog Entry with current_version = 0 and target_version = the new version. On the next Supervisor iteration, it sees the mismatch and sends a Deploy_Command."
>
> **Dev:** "What if no agent is connected yet?"
> **Domain expert:** "The Scheduler creates the catalog entry with node_id = NULL. The Supervisor skips it until an agent registers, then calls the Scheduler again to assign the node."
>
> **Dev:** "What if a deploy fails?"
> **Domain expert:** "The Deploy_Result handler sets the failed flag on the catalog entry. The Supervisor won't retry until the operator deploys a new version, which resets the flag."

## Flagged ambiguities

- "Desired state" and "expected state" were used interchangeably in early discussions. Resolved: for MVP, both collapse into the Service Catalog's target_version. The full three-state model (ADR-0005) is deferred until the scheduler is implemented.
- "Actual state" was a separate table. Resolved: replaced by Service Catalog's current_version column. The catalog is the single source of truth for both intent and reality.
- "Service definition" was ambiguous between the parser output type and the domain concept. Resolved: the parser type is Service_Definition; the domain concept is Abstract Service Definition (ASD).