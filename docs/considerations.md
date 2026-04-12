# Future Considerations

Features and capabilities not yet specified that may be worth considering.

## Image Building

### Remote Builds

Build images on a remote server rather than locally. Useful when:
- Local machine architecture differs from deployment targets
- Build resources (CPU, memory) are limited locally
- CI/CD systems need consistent build environments

```toml
[build]
remote = "ssh://builder@build-server"
local = true                              # use local builder for matching arch
```

### Multi-Architecture Builds

Build images for multiple architectures (amd64, arm64) in a single operation.

```toml
[build]
arch = ["amd64", "arm64"]
```

### Build Caching

Registry-based or local cache for Docker layer caching across builds.

```toml
[build.cache]
type = "registry"                         # or "local"
image = "registry.example.com/myapp-cache"
```

### Buildpack Support

Alternative to Dockerfile using Cloud Native Buildpacks (pack CLI).

```toml
[build]
pack.builder = "paketobuildpacks/builder:base"
pack.buildpacks = ["paketo-buildpacks/go"]
```

## Deployment Control

### Rolling Deploys

Deploy to a subset of nodes at a time, with configurable delays between batches.

```toml
[deploy]
limit = "25%"                             # or absolute number like 2
wait = 10                                 # seconds between batches
```

### Deploy Lock

Prevent concurrent deploys from multiple operators. A distributed lock stored on a designated node.

```bash
podmander lock acquire --message "Maintenance window"
podmander lock release
podmander lock status
```

### Drain Timeout

Time to wait for existing connections to complete before stopping old containers.

```toml
[service.api.deploy]
drain_timeout = 30                        # seconds
```

## Lifecycle Hooks

Scripts executed at specific points in the deployment lifecycle. Run locally on the operator's workstation.

| Hook | When |
|------|------|
| pre-connect | Before SSH connections are established |
| pre-build | Before image build starts |
| pre-deploy | Before deployment begins |
| post-deploy | After deployment completes |
| pre-service-boot | Before a service container starts |
| post-service-boot | After a service container starts |

```toml
[hooks]
path = ".podmander/hooks"
```

Hook scripts receive environment variables with deployment context:
- `PODMANDER_SERVICE` — service name
- `PODMANDER_VERSION` — version being deployed
- `PODMANDER_HOSTS` — comma-separated list of target hosts
- `PODMANDER_PERFORMER` — local username running the command

Non-zero exit code aborts the operation.

## Proxy Enhancements

### Path-Based Routing

Route requests to different services based on URL path prefix.

```toml
[service.api.ingress]
host = "example.com"
path_prefix = "/api"
strip_prefix = true                       # forward /api/users as /users
```

### Request/Response Buffering

Control whether the proxy buffers request and response bodies.

```toml
[service.api.ingress]
buffering.requests = true
buffering.responses = true
buffering.max_request_body = 40_000_000   # 40MB
buffering.memory = 2_000_000              # buffer in memory up to 2MB
```

### Custom Error Pages

Serve custom HTML error pages (4xx, 5xx) from the proxy when backends are unavailable.

```toml
[ingress]
error_pages_path = "public/errors"        # relative to project root
```

## Node Management

### Server Bootstrap

Automatically install container runtime and dependencies on fresh nodes.

```bash
podmander node setup web-1                # install Podman, configure user
```

### Audit Log

Record of commands executed on each node, stored on the nodes themselves.

```bash
podmander audit                           # show recent operations per node
podmander audit --node web-1              # specific node
```

## Container Runtime

### Docker Logging Driver

Configure container log driver and options.

```toml
[service.api.logging]
driver = "json-file"
options = { max-size = "10m", max-file = "3" }
```

### Container Labels

Custom labels applied to containers.

```toml
[service.api]
labels = { "app.version" = "1.0", "team" = "backend" }
```

### Retain Old Containers

Number of old container versions to keep for debugging or quick rollback.

```toml
retain_containers = 3                     # default: 5
```

## Registry

### Registry Authentication

Support for private registries with various authentication methods.

```toml
[registry]
server = "registry.example.com"
username = "deploy"
password_env = "REGISTRY_PASSWORD"        # read from environment
```

### Image Pruning

Automatic cleanup of old images on nodes.

```bash
podmander prune                           # remove unused images
podmander prune --older-than 7d
```

## Configuration

### Destinations

Deploy the same application to different environments using layered configuration.

```bash
podmander deploy -d staging               # uses deploy.toml + deploy.staging.toml
podmander deploy -d production
```

### Command Aliases

Define shortcuts for common command sequences.

```toml
[aliases]
console = "app exec api -- bin/console"
logs = "logs api --since 1h"
```

### Minimum Version Enforcement

Require a minimum Podmander version to deploy this configuration.

```toml
minimum_version = "1.2.0"
```

## Observability

### Proxy Metrics

Expose Prometheus metrics from the ingress proxy.

```toml
[ingress.metrics]
port = 9090
```

### Request Header Logging

Log specific request/response headers for debugging.

```toml
[service.api.ingress.logging]
request_headers = ["X-Request-ID", "Authorization"]
response_headers = ["X-Request-ID"]
```

## Cron / Scheduled Tasks

Run scheduled tasks using the same container image as the main service.

```toml
[service.api.cron]
cleanup = { schedule = "0 2 * * *", cmd = "bin/cleanup" }
reports = { schedule = "0 8 * * 1", cmd = "bin/weekly-report" }
```

Implementation would generate systemd timers on the target node.

## Asset Bridging

During deployments, serve both old and new static assets to handle in-flight requests referencing old asset URLs.

```toml
[service.web]
asset_path = "/app/public/assets"
```

Old assets are retained temporarily and mounted alongside new ones during the transition period.
