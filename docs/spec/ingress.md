# Ingress Specification

Public-facing reverse proxy via Caddy, generated from service definitions.

For architectural decisions and rationale, see:
- [ADR-0020](../adr/0020-caddy-for-ingress.md) — Caddy for ingress with generated Caddyfile

## Caddyfile Generation

Controller generates Caddyfile from service ingress declarations:

```toml
[service.api.ingress]
host = "api.example.com"
```

Becomes:

```
api.example.com {
    reverse_proxy worker-1:8080 worker-2:8080
}
```

Caddy runs as a Quadlet on the ingress node, following the same
generate-then-execute pattern as all other components. TLS certificates are
managed automatically via Let's Encrypt.

## Open Items

- Internal ingress mechanism
- Multi-node ingress (load balancing across multiple ingress nodes) — see [TLS certificate distribution](../open-questions.md#tls-certificate-distribution-across-multiple-ingress-nodes)
- TLS configuration for non-HTTP services
