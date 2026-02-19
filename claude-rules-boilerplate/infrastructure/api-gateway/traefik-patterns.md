# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Traefik Patterns

## Purpose
Traefik is a cloud-native edge router and reverse proxy that integrates natively with container orchestrators. These patterns define mandatory configuration standards for Traefik deployments. Every rule below is **mandatory** — not aspirational.

## TRF-01: Kubernetes IngressRoute CRD

**Traefik's IngressRoute CRD provides richer routing than standard Kubernetes Ingress.**

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: users-ingress
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`api.example.com`) && PathPrefix(`/api/v1/users`)
      kind: Rule
      middlewares:
        - name: rate-limit
          namespace: default
        - name: security-headers
          namespace: default
        - name: compress
          namespace: default
      services:
        - name: users-svc
          port: 8080
          weight: 100
          strategy: RoundRobin
          healthCheck:
            path: /health
            interval: 10s
            timeout: 5s
    - match: Host(`api.example.com`) && PathPrefix(`/api/v1/orders`)
      kind: Rule
      middlewares:
        - name: rate-limit
          namespace: default
        - name: security-headers
          namespace: default
      services:
        - name: orders-svc
          port: 8080
  tls:
    certResolver: letsencrypt
    domains:
      - main: api.example.com
        sans:
          - "*.api.example.com"
```

**Rules:**
- Use IngressRoute CRD instead of standard Kubernetes Ingress — it exposes full Traefik capabilities
- ALWAYS specify `entryPoints` explicitly — never rely on the default entrypoint
- Every route MUST reference the `websecure` entrypoint in production — never `web` (plain HTTP)
- Match rules use Traefik's expression syntax: combine `Host()`, `PathPrefix()`, `Headers()`, `Method()` with `&&` and `||`
- Middleware references MUST include namespace to avoid ambiguity in multi-namespace clusters
- Service `weight` is required when using weighted load balancing across multiple backends

## TRF-02: Middleware Chains

### Rate Limiting

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: rate-limit
  namespace: default
spec:
  rateLimit:
    average: 100
    burst: 200
    period: 1m
    sourceCriterion:
      ipStrategy:
        depth: 1
        excludedIPs:
          - 10.0.0.0/8
          - 172.16.0.0/12
```

- `average` is the sustained rate, `burst` allows temporary spikes above the average
- `burst` MUST be at least 2x `average` to handle legitimate traffic bursts
- Use `ipStrategy.depth: 1` to extract the real client IP from `X-Forwarded-For` (skip one proxy hop)
- Exclude internal IP ranges from rate limiting to avoid throttling health checks and internal traffic

### Security Headers

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: security-headers
  namespace: default
spec:
  headers:
    frameDeny: true
    contentTypeNosniff: true
    browserXssFilter: true
    referrerPolicy: strict-origin-when-cross-origin
    customResponseHeaders:
      X-Robots-Tag: noindex,nofollow
      Permissions-Policy: "camera=(), microphone=(), geolocation=()"
    stsSeconds: 31536000
    stsIncludeSubdomains: true
    stsPreload: true
    contentSecurityPolicy: "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'"
    customRequestHeaders:
      X-Forwarded-Proto: https
```

**Mandatory security headers (minimum baseline):**

| Header | Value | Purpose |
|--------|-------|---------|
| `X-Frame-Options` | `DENY` | Prevent clickjacking |
| `X-Content-Type-Options` | `nosniff` | Prevent MIME sniffing |
| `X-XSS-Protection` | `1; mode=block` | XSS protection (legacy browsers) |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains; preload` | Force HTTPS |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Control referrer leakage |
| `Content-Security-Policy` | `default-src 'self'` (adjust per application) | Prevent XSS and injection |

### Compression

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: compress
  namespace: default
spec:
  compress:
    excludedContentTypes:
      - image/png
      - image/jpeg
      - image/gif
      - application/octet-stream
    minResponseBodyBytes: 1024
```

- Exclude already-compressed content types (images, binary streams)
- Set `minResponseBodyBytes: 1024` to avoid compressing tiny responses (compression overhead exceeds savings)

### Retry

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: retry
  namespace: default
spec:
  retry:
    attempts: 3
    initialInterval: 100ms
```

- Use retries only for idempotent endpoints (`GET`, `PUT` with idempotency key, `DELETE`)
- NEVER apply retry middleware to non-idempotent `POST` routes
- `initialInterval` uses exponential backoff — 100ms, 200ms, 400ms for 3 attempts

### Strip Prefix

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: strip-api-prefix
  namespace: default
spec:
  stripPrefix:
    prefixes:
      - /api/v1
    forceSlash: false
```

- Use to remove gateway-specific path prefixes before forwarding to backends
- Set `forceSlash: false` to avoid adding a trailing slash when the prefix is stripped

### Middleware Chain (Combine Multiple Middlewares)

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: standard-chain
  namespace: default
spec:
  chain:
    middlewares:
      - name: rate-limit
      - name: security-headers
      - name: compress
      - name: strip-api-prefix
```

**Rules:**
- Use `chain` middleware to define reusable middleware stacks — do not repeat middleware lists on every route
- Middleware execution order matches the list order — rate limiting MUST come before authentication, authentication before transformation
- Define a `standard-chain` for common routes and specialized chains for specific requirements
- Every production IngressRoute MUST include at minimum: rate limiting, security headers, and compression

## TRF-03: Let's Encrypt Auto-Cert (ACME)

```yaml
# Traefik static configuration (values.yaml for Helm)
additionalArguments:
  - "--certificatesresolvers.letsencrypt.acme.email=devops@example.com"
  - "--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json"
  - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
  - "--certificatesresolvers.letsencrypt.acme.caserver=https://acme-v02.api.letsencrypt.org/directory"

# For DNS challenge (wildcard certs)
additionalArguments:
  - "--certificatesresolvers.letsencrypt.acme.email=devops@example.com"
  - "--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json"
  - "--certificatesresolvers.letsencrypt.acme.dnschallenge=true"
  - "--certificatesresolvers.letsencrypt.acme.dnschallenge.provider=route53"
  - "--certificatesresolvers.letsencrypt.acme.dnschallenge.resolvers=1.1.1.1:53,8.8.8.8:53"
```

**Rules:**
- Use TLS challenge for single-domain certs, DNS challenge for wildcard certs
- ALWAYS use the production ACME server in production — the staging server (`acme-staging-v02`) is for testing only
- `acme.json` MUST be persisted on a volume — losing it means re-issuing all certificates (rate limits apply)
- Set file permissions on `acme.json` to `600` — it contains private keys
- Monitor certificate expiry — Let's Encrypt certs expire after 90 days, Traefik renews at 30 days before expiry
- For high-availability deployments, use a distributed cert store (Consul, etcd) or cert-manager with Traefik

## TRF-04: Docker Provider (for docker-compose)

```yaml
# docker-compose.yml
services:
  traefik:
    image: traefik:v3.2
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=proxy"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--certificatesresolvers.letsencrypt.acme.email=devops@example.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - letsencrypt:/letsencrypt
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(`traefik.example.com`)"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.middlewares=dashboard-auth"
      - "traefik.http.middlewares.dashboard-auth.basicauth.users=admin:$$apr1$$xyz$$hashedpassword"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"

  users-svc:
    image: users-svc:latest
    networks:
      - proxy
      - internal
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.users.rule=Host(`api.example.com`) && PathPrefix(`/api/v1/users`)"
      - "traefik.http.routers.users.entrypoints=websecure"
      - "traefik.http.routers.users.tls.certresolver=letsencrypt"
      - "traefik.http.routers.users.middlewares=rate-limit@docker,security-headers@docker"
      - "traefik.http.services.users.loadbalancer.server.port=8080"
      - "traefik.http.services.users.loadbalancer.healthcheck.path=/health"
      - "traefik.http.services.users.loadbalancer.healthcheck.interval=10s"

networks:
  proxy:
    external: true
  internal:
    internal: true

volumes:
  letsencrypt:
```

**Rules:**
- Set `exposedbydefault=false` — services MUST explicitly opt in with `traefik.enable=true`
- Mount Docker socket as read-only (`:ro`) — Traefik only reads container labels
- Use a dedicated `proxy` network — backend services connect to both `proxy` (for Traefik) and `internal` (for inter-service)
- ALWAYS configure HTTP-to-HTTPS redirect on the `web` entrypoint
- Service port MUST be explicitly set via `loadbalancer.server.port` — do not rely on auto-detection
- Health checks MUST be configured for every service

## TRF-05: Entrypoints and Routers

```yaml
# Static configuration
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: letsencrypt
        domains:
          - main: example.com
            sans:
              - "*.example.com"
    transport:
      respondingTimeouts:
        readTimeout: 30s
        writeTimeout: 30s
        idleTimeout: 120s
  metrics:
    address: ":9090"
```

**Entrypoint configuration rules:**

| Entrypoint | Port | Purpose | TLS |
|-----------|:----:|---------|:---:|
| `web` | 80 | HTTP (redirect only) | No |
| `websecure` | 443 | HTTPS (all production traffic) | Yes |
| `metrics` | 9090 | Prometheus metrics (internal only) | No |
| `traefik` | 8080 | Dashboard/API (internal only) | Optional |

**Rules:**
- `web` entrypoint MUST redirect to `websecure` with `permanent: true` (HTTP 301)
- `websecure` entrypoint MUST have TLS enabled with a valid cert resolver
- `metrics` and `traefik` entrypoints MUST NOT be exposed externally — bind to internal network only
- Set `readTimeout` and `writeTimeout` based on the slowest backend (default: 30s)
- Set `idleTimeout` to allow connection reuse without holding resources indefinitely (default: 120s)

## TRF-06: Dashboard Security

```yaml
# Kubernetes — secure dashboard with IngressRoute
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-dashboard
  namespace: traefik
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`traefik.internal.example.com`)
      kind: Rule
      middlewares:
        - name: dashboard-ipwhitelist
        - name: dashboard-auth
      services:
        - name: api@internal
          kind: TraefikService
  tls:
    certResolver: letsencrypt
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: dashboard-ipwhitelist
  namespace: traefik
spec:
  ipAllowList:
    sourceRange:
      - 10.0.0.0/8
      - 192.168.0.0/16
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: dashboard-auth
  namespace: traefik
spec:
  basicAuth:
    secret: dashboard-credentials
```

**Rules:**
- Dashboard MUST NOT be publicly accessible — restrict by IP allowlist AND authentication
- Use a separate hostname for the dashboard (`traefik.internal.example.com`) — never expose on the main API domain
- BasicAuth credentials MUST be stored in a Kubernetes Secret, never in plain text in middleware configuration
- In production, prefer disabling the dashboard entirely (`--api.dashboard=false`) and use Prometheus/Grafana for monitoring
- If the dashboard must be enabled, enable read-only mode (`--api.dashboard=true --api.insecure=false`)

## TRF-07: Observability Configuration

```yaml
# Static configuration
metrics:
  prometheus:
    entryPoint: metrics
    addEntryPointsLabels: true
    addRoutersLabels: true
    addServicesLabels: true
    buckets:
      - 0.01
      - 0.05
      - 0.1
      - 0.25
      - 0.5
      - 1.0
      - 2.5
      - 5.0
      - 10.0

tracing:
  otlp:
    http:
      endpoint: http://otel-collector.observability.svc.cluster.local:4318/v1/traces

accessLog:
  format: json
  filters:
    statusCodes:
      - "400-599"
    retryAttempts: true
    minDuration: 1s
  fields:
    defaultMode: keep
    headers:
      defaultMode: drop
      names:
        X-Request-Id: keep
        X-Trace-Id: keep
        User-Agent: keep
        Content-Type: keep
```

**Rules:**
- Prometheus metrics MUST be enabled on a dedicated `metrics` entrypoint — never on the public-facing entrypoint
- Enable `addRoutersLabels` and `addServicesLabels` for per-route and per-service metrics granularity
- Access log MUST use JSON format for machine parsing
- Filter access logs to reduce volume: log only errors (400-599), retries, and slow requests (> 1s)
- Drop request/response headers from access logs by default — keep only non-sensitive tracing headers
- Enable OTLP tracing to send spans to an OpenTelemetry collector for distributed tracing

## Anti-Patterns (FORBIDDEN)

- Using standard Kubernetes Ingress instead of IngressRoute CRD when Traefik is the ingress controller
- Exposing services by default (`exposedbydefault=true`) in Docker provider
- Serving plain HTTP traffic in production without redirect to HTTPS
- Exposing the Traefik dashboard publicly without IP allowlist and authentication
- Applying retry middleware to non-idempotent POST endpoints
- Losing `acme.json` by not persisting it on a volume (causes Let's Encrypt rate limit issues)
- Mounting Docker socket without read-only flag
- Missing health checks on load-balanced services
- Exposing metrics or dashboard entrypoints on public-facing ports
- Hardcoding BasicAuth credentials in middleware configuration instead of using Kubernetes Secrets
