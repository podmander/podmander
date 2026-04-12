# Scenarios

Operator workflows for the Podmander system.

## Initialize Controller

The operator sets up a new fleet by initializing the controller on a host.

**Preconditions**: None (fresh host).

**Steps**:

1. Operator runs `podctl init`.
2. Controller verifies preconditions: Podman installed and functional, systemd
   user session available, SQLite available, network port accessible.
3. Controller creates the SQLite database with the required schema.
4. Controller generates its cryptographic identity: CURVE keypair for ZeroMQ
   transport encryption, master key setup (passphrase or key file).
5. Controller generates an initial join token.
6. Controller starts its services: ZeroMQ listener for agent connections,
   supervisor loop (starts idle with no agents).

**Postconditions**: Controller is running, database is initialized, join token
is available for node enrollment.

## Register Node

The operator enrolls a node into an existing fleet. This applies to any node,
including the controller host itself.

**Preconditions**: Controller is running. Operator has a valid join token.

**Steps**:

1. Operator runs `podctl join <token>` on the new node.
2. Agent verifies local preconditions: Podman installed and functional, systemd
   user session available, network connectivity to controller.
3. Agent connects to the controller and presents the join token over ZeroMQ.
4. Controller validates the token and registers the node in its database
   (identity, default metadata).
5. Agent starts and reports idle status to the controller.
6. Supervisor loop incorporates the new node into its state.

**Postconditions**: Node is registered in the fleet, agent is running and
reporting status. Node has no labels, capabilities, or workloads yet.

## Configure Node

The operator assigns labels and capabilities to a registered node so the
scheduler can make informed placement decisions.

**Preconditions**: Node is registered in the fleet and reporting status.

**Steps**:

1. Operator runs `podctl node configure <node> --label role=worker --capability zfs`
   (or similar).
2. Controller validates the labels and capabilities.
3. Controller updates the node's metadata in the database.
4. Scheduler re-evaluates placements if any pending services match the new
   labels or capabilities.

**Postconditions**: Node metadata is updated. The node is eligible for
placement of services that match its labels and capabilities.

## Deploy Stack

The operator deploys a new stack or updates an existing one.

**Preconditions**: Controller is running. At least one node is registered and
configured. Operator has a TOML stack file.

**Steps**:

1. Operator runs `podctl deploy <file>`.
2. Controller parses and validates the TOML stack file.
3. Controller resolves secrets referenced in the stack: values are read from
   environment variables, password manager CLI output, or inline definitions.
4. Controller encrypts and stores secrets in SQLite.
5. Controller stores the stack definition as desired state, creating a new
   service version for each service that changed (or all services on first
   deploy).
6. Scheduler evaluates placement rules against available nodes and their
   labels/capabilities, producing expected state.
7. Controller sends Quadlet definitions and decrypted secrets to the targeted
   agents over ZeroMQ.
8. Agents write Quadlet files to disk, store secrets in Podman secret store.
9. Agents pull container images if not already present.
10. Agents reload systemd and start the services.
11. If any services declare ingress rules, the controller generates a Caddyfile
    incorporating their domain names and routing rules, and sends it to the
    agent on the ingress node. That agent writes the Caddyfile and reloads
    Caddy, which provisions TLS certificates for the declared domains.
12. Agents report actual state back to the controller.
13. Supervisor loop confirms expected state matches actual state.

**Postconditions**: Services are running on their assigned nodes. Service
versions are recorded. Secrets are stored encrypted on the controller and
delivered to the relevant agents. If ingress rules were declared, Caddy is
serving traffic for the specified domains with TLS.

## Scale Service

The operator changes the number of replicas for a running service.

**Preconditions**: Stack is deployed. Service is running.

**Steps**:

1. Operator runs `podctl scale <stack>/<service> --replicas <N>`.
2. Controller validates the request: service exists, new replica count is valid
   for the service's placement mode (e.g., cannot scale a singleton beyond 1).
3. Controller updates the desired state with the new replica count. No new
   service version is created — the service definition has not changed.
4. Scheduler evaluates placement for the delta: selects nodes for new replicas
   (scale up) or marks excess replicas for removal (scale down).
5. Controller sends Quadlet definitions to agents receiving new replicas, or
   instructs agents to stop and remove Quadlets for excess replicas.
6. Agents carry out the changes and report actual state.
7. Supervisor loop confirms the new expected state matches actual state.

**Postconditions**: The service is running the requested number of replicas.
Desired and expected state reflect the new count.

## Update Service

The operator updates a running service (e.g., new image tag, changed
configuration, modified resource limits) without redeploying the entire stack.

**Preconditions**: Stack is deployed. Service is running.

**Steps**:

1. Operator runs `podctl deploy <file>` with an updated TOML file, or
   `podctl update <stack>/<service> --image <new-image>` (or similar).
2. Controller parses the change and validates it.
3. Controller resolves any new or changed secrets.
4. Controller creates a new service version capturing the updated definition.
5. Controller updates the desired state.
6. Scheduler re-evaluates placement. Existing placements may be reused if
   node assignments are still valid.
7. Controller sends updated Quadlet definitions and secrets to the targeted
   agents.
8. Agents replace Quadlet files, pull the new image if needed, reload systemd,
   and restart the service.
9. Agents report actual state back to the controller.
10. Supervisor loop confirms expected state matches actual state.

**Postconditions**: The service is running the new version. The previous
version is retained in the controller's version history for potential rollback.

## Roll Back Service

The operator reverts a service to a previous version.

**Preconditions**: Service has more than one version in its history.

**Steps**:

1. Operator runs `podctl rollback <stack>/<service>` (defaults to previous
   version) or `podctl rollback <stack>/<service> --version <N>` (specific
   version).
2. Controller validates that the target version exists and has not been pruned.
3. Controller marks the target version as the active desired state. This does
   not create a new version — it reactivates an existing one.
4. Controller resolves secrets for the target version. If the version
   references secrets that have since been updated, the current secret values
   are used (secrets have their own lifecycle).
5. Scheduler re-evaluates placement using the target version's definition.
6. Controller sends the rolled-back Quadlet definitions and secrets to agents.
7. Agents replace Quadlet files, pull the image if no longer cached, reload
   systemd, and restart the service.
8. Agents report actual state back to the controller.
9. Supervisor loop confirms expected state matches actual state.

**Postconditions**: The service is running the target version. The version that
was replaced remains in the history. If the service uses ZFS volumes with
deploy-linked snapshots, the volume can optionally be rolled back to the
matching snapshot.

## Update Ingress Configuration

The operator changes a service's ingress settings — domain names, TLS options,
or routing rules — which requires regenerating the Caddy configuration on the
ingress node.

**Preconditions**: Stack is deployed. Service is running. An ingress node with
Caddy is operational.

**Steps**:

1. Operator updates the ingress section of the TOML stack file and runs
   `podctl deploy <file>`.
2. Controller parses the change and identifies that ingress configuration has
   changed.
3. Controller creates a new service version (the service definition changed,
   even if the container itself is unaffected).
4. Controller regenerates the Caddyfile incorporating the updated domain names
   and routing rules.
5. Controller sends the updated Caddyfile to the agent on the ingress node.
6. Agent writes the Caddyfile to disk and reloads Caddy.
7. Caddy picks up the new configuration and provisions TLS certificates via
   Let's Encrypt for any new domains.
8. Agent reports success to the controller.
9. The service containers themselves may not need restarting — the controller
   only pushes updated Quadlets to service agents if the container definition
   also changed.

**Postconditions**: Caddy is serving traffic for the updated domains. A new
service version is recorded. The previous Caddy configuration can be restored
by rolling back the service version.
