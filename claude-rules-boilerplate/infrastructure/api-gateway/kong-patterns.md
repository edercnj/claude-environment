# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Kong Gateway Patterns

## Purpose
Kong is an open-source API gateway built on NGINX and OpenResty. These patterns define mandatory configuration standards for Kong deployments. Every rule below is **mandatory** — not aspirational.

## KNG-01: Declarative Configuration with decK

**All Kong configuration MUST be managed declaratively via decK (deck).**

```yaml
# kong.yaml — root declarative configuration
_format_version: "3.0"
_transform: true

services:
  - name: users-service
    url: http://users-svc.default.svc.cluster.local:8080
    connect_timeout: 5000
    write_timeout: 10000
    read_timeout: 30000
    retries: 3
    routes:
      - name: users-route
        paths:
          - /api/v1/users
        strip_path: true
        protocols:
          - https
        methods:
          - GET
          - POST
          - PUT
          - DELETE
    plugins:
      - name: rate-limiting
        config:
          minute: 100
          policy: redis
          redis_host: redis.default.svc.cluster.local
```

**Rules:**
- NEVER configure Kong via the Admin API in production — all changes go through decK and Git
- Store `kong.yaml` in version control alongside the service it routes to
- Use `deck diff` in CI to preview changes before applying
- Use `deck sync` (not `deck reset`) to apply changes — reset destroys and recreates everything
- Split large configurations into multiple files: `deck sync --state services/ --state plugins/`

## KNG-02: Consumer, Service, and Route Model

**Entities and their relationships:**

| Entity | Purpose | Key Fields |
|--------|---------|------------|
| **Service** | Represents a backend API (upstream) | `name`, `url`, `connect_timeout`, `retries` |
| **Route** | Maps incoming requests to a Service | `paths`, `methods`, `headers`, `protocols`, `strip_path` |
| **Consumer** | Represents an API client (application or user) | `username`, `custom_id` |
| **Plugin** | Attaches behavior to Service, Route, Consumer, or globally | `name`, `config`, scoping entity |
| **Upstream** | Advanced load balancing target for a Service | `name`, `targets`, `healthchecks` |

**Rules:**
- One Service per backend microservice — do NOT create multiple Services for the same backend
- Routes MUST have explicit `methods` — never allow all HTTP methods by default
- Routes MUST use `protocols: [https]` in production — never allow plain HTTP
- Consumer `username` MUST match the application name in the service registry
- Plugins scoped to a Route override plugins scoped to a Service, which override global plugins

## KNG-03: Plugin Ecosystem

### Rate Limiting

```yaml
plugins:
  - name: rate-limiting
    config:
      minute: 100
      hour: 5000
      policy: redis
      redis_host: redis.default.svc.cluster.local
      redis_port: 6379
      redis_database: 0
      fault_tolerant: true
      hide_client_headers: false
```

- Use `policy: redis` for multi-node deployments — `local` policy is per-node and inconsistent
- Set `fault_tolerant: true` so rate limiting degrades gracefully if Redis is unreachable
- Keep `hide_client_headers: false` so clients see `X-RateLimit-Remaining` and `X-RateLimit-Limit`

### JWT Authentication

```yaml
plugins:
  - name: jwt
    config:
      uri_param_names: []
      cookie_names: []
      header_names:
        - Authorization
      claims_to_verify:
        - exp
      key_claim_name: iss
      secret_is_base64: false
      run_on_preflight: true
```

- NEVER accept tokens via `uri_param_names` (query parameters) — tokens leak in logs and browser history
- Always verify `exp` claim — never trust tokens without expiration
- Use `header_names: [Authorization]` with `Bearer` scheme as the only token transport

### CORS

```yaml
plugins:
  - name: cors
    config:
      origins:
        - "https://app.example.com"
        - "https://admin.example.com"
      methods:
        - GET
        - POST
        - PUT
        - DELETE
        - PATCH
      headers:
        - Authorization
        - Content-Type
        - X-Request-Id
      exposed_headers:
        - X-Request-Id
        - X-Trace-Id
      credentials: true
      max_age: 86400
      preflight_continue: false
```

- NEVER set `origins: ["*"]` in production
- Set `preflight_continue: false` so Kong handles `OPTIONS` — do not forward pre-flight to backends

### Request Transformer

```yaml
plugins:
  - name: request-transformer
    config:
      add:
        headers:
          - "X-Gateway: kong"
          - "X-Request-Start: $(now)"
      remove:
        headers:
          - X-Internal-Debug
      rename:
        headers:
          - "X-Custom-Auth:Authorization"
      replace:
        headers:
          - "Host:users-svc.internal"
```

- Use to inject internal headers that backends expect (tenant ID, region, trace context)
- Use to strip headers that clients should not be able to set (internal routing headers)
- NEVER use request-transformer for heavy body rewriting — use a dedicated transformation service

### Prometheus Metrics

```yaml
plugins:
  - name: prometheus
    config:
      per_consumer: true
      status_code_metrics: true
      latency_metrics: true
      bandwidth_metrics: true
      upstream_health_metrics: true
```

- Enable globally — do not scope to individual services
- Set `per_consumer: true` to track usage per API client
- Scrape from Kong's status API: `http://kong-admin:8001/metrics`
- Alert on: `kong_http_requests_total{code=~"5.."}` rate increase, `kong_latency_bucket` p99 degradation

## KNG-04: DB-less Mode

**Use DB-less mode for immutable, reproducible deployments.**

```yaml
# kong.conf
database = off
declarative_config = /etc/kong/kong.yaml
```

**When to use DB-less:**
- Kubernetes deployments where configuration is managed via ConfigMap or CRD
- CI/CD pipelines that build and deploy gateway configuration as an artifact
- Environments that require immutable infrastructure (no runtime state mutation)

**When to use DB mode:**
- When multiple Kong nodes need shared runtime state (e.g., OAuth2 token storage)
- When using plugins that require database persistence (e.g., `oauth2`)
- When using the Kong Admin API for dynamic consumer management

**Rules:**
- DB-less is the default recommendation — use DB mode only when a plugin explicitly requires it
- In DB-less mode, the Admin API is read-only — all mutations go through `kong.yaml` and restart/reload
- Store `kong.yaml` in Git and deploy via CI/CD pipeline — never hand-edit on running instances

## KNG-05: Kubernetes Ingress Controller (KIC)

**Kong Ingress Controller maps Kubernetes Ingress resources to Kong configuration.**

```yaml
# Ingress resource with Kong annotations
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: users-ingress
  annotations:
    konghq.com/strip-path: "true"
    konghq.com/protocols: "https"
    konghq.com/plugins: "users-rate-limit,users-jwt"
spec:
  ingressClassName: kong
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /api/v1/users
            pathType: Prefix
            backend:
              service:
                name: users-svc
                port:
                  number: 8080
---
# KongPlugin CRD for rate limiting
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: users-rate-limit
config:
  minute: 100
  policy: redis
  redis_host: redis.default.svc.cluster.local
plugin: rate-limiting
---
# KongPlugin CRD for JWT
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: users-jwt
plugin: jwt
config:
  header_names:
    - Authorization
  claims_to_verify:
    - exp
```

**Rules:**
- Use `ingressClassName: kong` explicitly — never rely on default ingress class
- Plugin configuration goes in `KongPlugin` CRD, not in Ingress annotations
- Reference plugins by name in `konghq.com/plugins` annotation (comma-separated)
- Use `KongClusterPlugin` for plugins that apply across namespaces (e.g., global rate limits)
- KIC and decK are mutually exclusive — pick one management approach per cluster

## KNG-06: Upstream Health Checks and Load Balancing

```yaml
upstreams:
  - name: users-upstream
    algorithm: round-robin
    hash_on: none
    slots: 10000
    healthchecks:
      active:
        type: http
        http_path: /health
        healthy:
          interval: 5
          successes: 3
        unhealthy:
          interval: 5
          http_failures: 3
          tcp_failures: 3
          timeouts: 3
      passive:
        type: http
        healthy:
          successes: 5
        unhealthy:
          http_failures: 3
          tcp_failures: 3
          timeouts: 3
    targets:
      - target: users-svc-1.internal:8080
        weight: 100
      - target: users-svc-2.internal:8080
        weight: 100
```

- Enable BOTH active and passive health checks — passive alone is reactive, active alone misses in-flight failures
- Active health check interval: 5 seconds (balance between responsiveness and probe traffic)
- Use `algorithm: round-robin` as default — switch to `consistent-hashing` only for stateful backends
- Set `slots: 10000` for fine-grained weight distribution across targets

## Anti-Patterns (FORBIDDEN)

- Configuring Kong via Admin API in production without version control
- Using `local` rate limiting policy in multi-node deployments
- Accepting JWT tokens in query parameters
- Setting CORS origins to `*` in production
- Mixing KIC and decK management in the same cluster
- Running DB mode when DB-less mode is sufficient
- Hardcoding upstream targets instead of using service discovery or Kubernetes DNS
- Disabling health checks on upstreams
