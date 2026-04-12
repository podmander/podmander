# Architecture Specification

Container orchestration system for small multi-node deployments. Generates
configuration for specialized tools rather than reimplementing their
functionality.

For architectural decisions and rationale, see:
- [ADR-0001](../adr/0001-controller-agent-topology.md) — Controller-agent topology
- [ADR-0005](../adr/0005-three-state-model.md) — Three-state model
- [ADR-0006](../adr/0006-continuous-supervisor-loop.md) — Supervisor loop
- [ADR-0007](../adr/0007-services-as-systemd-units.md) — Services as systemd units
- [ADR-0008](../adr/0008-one-operation-per-service.md) — One operation per service

## System Topology

```mermaid
graph TB
    subgraph Operator
        CLI[podctl CLI]
    end

    subgraph ControllerNode[Controller Node]
        CTRL[Controller Daemon]
        DB[(SQLite)]
        CTRL --> DB
    end

    subgraph WorkerNodes[Worker Nodes]
        subgraph Node1[Node 1]
            A1[Agent]
            SD1[systemd]
            P1[Podman]
            A1 --> SD1
            A1 --> P1
        end
        subgraph Node2[Node 2]
            A2[Agent]
            SD2[systemd]
            P2[Podman]
            A2 --> SD2
            A2 --> P2
        end
        subgraph NodeN[Node N]
            AN[Agent]
            SDN[systemd]
            PN[Podman]
            AN --> SDN
            AN --> PN
        end
    end

    CLI -->|API| CTRL
    CTRL <-->|ZeroMQ CURVE| A1
    CTRL <-->|ZeroMQ CURVE| A2
    CTRL <-->|ZeroMQ CURVE| AN
    CTRL -->|SSH/SCP| Node1
    CTRL -->|SSH/SCP| Node2
    CTRL -->|SSH/SCP| NodeN
```

## Core Pattern

The orchestrator generates configuration; other tools execute:

| Generated config | Executing tool |
|------------------|----------------|
| Quadlet files | systemd + Podman |
| Restic config + timers | systemd + Restic |
| Caddyfile | Caddy |
| CoreDNS zone files | CoreDNS |

## Controller

Long-running daemon on a designated node. Responsibilities:

- API endpoint for CLI commands
- Scheduler: decide service placement based on constraints and node capacity
- Supervisor loop: continuously compare expected vs actual state, repair drift
- Secret storage: encrypted at rest, decrypted for delivery to agents
- Config generation: produce Quadlets, Caddyfiles, zone files from TOML definitions

SQLite stores:
- Desired state (user declarations from TOML)
- Expected state (what should be deployed where)
- Actual state (last reported by agents)
- Secrets (encrypted with libsodium secretbox)
- Node metadata, labels, and capabilities
- Version history for services and infrastructure configs

### Supervisor Loop

```mermaid
flowchart TD
    START([Loop start]) --> WAIT[Wait for reconciliation interval]
    WAIT --> COLLECT[Collect actual state from agent heartbeats]
    COLLECT --> COMPARE{Compare expected vs actual}

    COMPARE -->|Match| WAIT
    COMPARE -->|Divergence| POLICY{Check policy}

    POLICY -->|auto_repair| QUEUE[Queue repair action]
    POLICY -->|alert_only| ALERT[Emit alert]

    QUEUE --> EXECUTE[Execute queued actions]
    ALERT --> WAIT
    EXECUTE --> WAIT
```

There is no separate "recovery mode." Startup, steady state, and failure recovery
all use the same loop. A configurable grace period prevents false alerts during
cluster boot.

### Controller High Availability (Future)

Multiple controller instances share a CURVE keypair. State replication ensures
all instances have consistent data. Only one instance (leader) accepts commands
at a time. Agents connect to a floating VIP or DNS name; on failover, they
reconnect to the new leader without re-enrollment.

```mermaid
graph TB
    subgraph ControllerCluster[Controller Cluster]
        C1[Controller 1 - Leader]
        C2[Controller 2 - Standby]
        C3[Controller 3 - Standby]
        C1 <-->|State replication| C2
        C2 <-->|State replication| C3
        C3 <-->|State replication| C1
    end

    VIP[Floating VIP / DNS]
    VIP --> C1

    A1[Agent 1] <-->|ZeroMQ| VIP
    A2[Agent 2] <-->|ZeroMQ| VIP
    A3[Agent 3] <-->|ZeroMQ| VIP

    CLI[podctl] -->|API| VIP
```

Single-controller mode is the initial implementation. The specific consensus
protocol for leader election and state replication will be determined during the
HA design phase.

## Agents

Long-running daemon on each worker node. Responsibilities:

- Maintain ZeroMQ connection to controller
- Report node status via periodic heartbeat
- Execute deploy/stop/restart commands for services
- Execute config updates for infrastructure components (Caddy, CoreDNS)
- Query Podman and systemd for actual state
- Verify file integrity after SSH transfers

Agents are stateless beyond Quadlet files on disk. On restart, they rediscover
existing workloads by scanning the filesystem and querying Podman.

### Agent State Machine

**Connection state:**

```mermaid
stateDiagram-v2
    [*] --> DISCONNECTED : agent starts

    DISCONNECTED --> ENROLLING : connect + send join token
    DISCONNECTED --> DISCONNECTED : retry with backoff

    ENROLLING --> CONNECTED : enrollment confirmed
    ENROLLING --> DISCONNECTED : enrollment rejected

    CONNECTED --> DISCONNECTED : connection lost
    CONNECTED --> CONNECTED : heartbeat, commands
```

| State | Meaning |
|-------|---------|
| DISCONNECTED | No ZeroMQ connection to controller |
| ENROLLING | Connected, join token sent, awaiting confirmation |
| CONNECTED | Enrolled and operational |

**Service state (per service):**

```mermaid
stateDiagram-v2
    [*] --> UNKNOWN : agent starts
    [*] --> NOT_PRESENT : no Quadlet on disk

    UNKNOWN --> RUNNING : discover running service
    UNKNOWN --> STOPPED : discover stopped service
    UNKNOWN --> NOT_PRESENT : no Quadlet found

    NOT_PRESENT --> DEPLOYING : deploy command

    DEPLOYING --> RUNNING : deploy succeeds
    DEPLOYING --> DEPLOY_FAILED : deploy fails

    DEPLOY_FAILED --> DEPLOYING : controller ack + retry
    DEPLOY_FAILED --> STOPPED : controller ack + abort

    RUNNING --> DEPLOYING : deploy command (new version)
    RUNNING --> STOPPED : stop command
    RUNNING --> RUNNING : restart command

    STOPPED --> DEPLOYING : deploy command
    STOPPED --> RUNNING : start command
    STOPPED --> NOT_PRESENT : remove command
```

| State | Meaning |
|-------|---------|
| UNKNOWN | Agent just started, hasn't queried this service yet |
| RUNNING | Systemd unit active, container running |
| STOPPED | Systemd unit exists but inactive |
| DEPLOYING | Deploy in progress |
| DEPLOY_FAILED | Last deploy failed, awaiting controller ack |
| NOT_PRESENT | No Quadlet file for this service |

**Infrastructure component state (per component):**

```mermaid
stateDiagram-v2
    [*] --> NOT_PRESENT : no config file

    NOT_PRESENT --> DEPLOYING : config command

    DEPLOYING --> RUNNING : config succeeds + service up
    DEPLOYING --> CONFIG_FAILED : validation fails
    DEPLOYING --> SERVICE_DOWN : config ok but service won't start

    CONFIG_FAILED --> DEPLOYING : controller retry

    RUNNING --> DEPLOYING : config command (new version)
    RUNNING --> DRIFT : hash mismatch detected
    RUNNING --> SERVICE_DOWN : service crashes

    DRIFT --> DEPLOYING : auto-repair
    DRIFT --> RUNNING : manual override (accept drift)

    SERVICE_DOWN --> RUNNING : service recovers
    SERVICE_DOWN --> DEPLOYING : redeploy config
```

| State | Meaning |
|-------|---------|
| RUNNING | Config deployed, service running, hash matches |
| DRIFT | Service running, config hash doesn't match expected |
| CONFIG_FAILED | Last config deploy failed validation |
| SERVICE_DOWN | Config correct but service not running |

## Managed Resources

### Application Services

Deployed as Quadlet files. Per-node placement with replication support.

```
[service.api]
image = "myapp:v2.1"
replicas = 2
```

### Infrastructure Components

| Component | Config file | Location | Reload |
|-----------|-------------|----------|--------|
| Caddy | Caddyfile | Ingress node(s) | `caddy reload` |
| CoreDNS | Zone files | DNS node(s) | Auto-reload on file change |
| Restic | Config + timers | Backup node(s) | `systemctl daemon-reload` |

Infrastructure configs use the same versioning model as services
([ADR-0024](../adr/0024-infrastructure-component-versioning.md)).

### Drift Detection and Auto-Repair

On each heartbeat, agents report config hashes for infrastructure components. If
the hash doesn't match expected, the controller detects drift.

Default policy: auto-repair. The controller redeploys the expected config,
overwriting manual changes. Podmander is the source of truth.

## Privilege Model

The agent runs as root on all nodes
([ADR-0012](../adr/0012-rootless-containers-rootful-agent.md)). Two container
modes per node:

| Mode | Container User | Capabilities |
|------|----------------|--------------|
| Rootless | Unprivileged user via Podman user namespaces | Podman, user systemd, bind-mount volumes |
| Rootful | root | Above + volume snapshots, privileged ports |

Typical setup:
- Application nodes: rootless containers
- Ingress node: rootful containers (ports 80/443)
- Storage nodes: rootful containers (ZFS/BTRFS snapshots)

## Failure Scenarios

### Agent Crash

- Services keep running (systemd units)
- Controller marks agent as unresponsive after missed heartbeats
- Agent restarts, reconnects, reports status
- Supervisor loop reconciles any drift

### Controller Crash (Single Controller)

- Agents detect disconnect, enter DISCONNECTED state
- Services keep running on all nodes
- No new deploys possible until controller restarts
- Operator restarts controller; agents reconnect
- Supervisor loop reconciles

### Controller Failover (HA Mode)

- Consensus mechanism detects leader failure, elects new leader
- New leader has replicated state
- Agents reconnect to floating endpoint (same CURVE keypair)
- Supervisor loop resumes

### Node Network Partition

- Controller marks partitioned agent as disconnected
- Services on partitioned node keep running
- When connectivity restores, agent reconnects
- Supervisor loop reconciles version mismatches

## Open Items

- Upgrade path for Podmander itself (controller and agent binaries)
- Consensus protocol selection for controller HA
- Agent resource reporting (CPU, memory, disk) for scheduler decisions
- Rate limiting on auto-repair to prevent thrashing
