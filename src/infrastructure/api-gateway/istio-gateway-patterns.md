# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Istio Gateway Patterns

## Purpose
Istio Gateway and VirtualService resources control ingress traffic into the service mesh. These patterns define mandatory configuration standards for Istio-based API gateway deployments. Every rule below is **mandatory** — not aspirational.

## IST-01: Gateway and VirtualService Configuration

**Gateway defines the entry point (ports, hosts, TLS). VirtualService defines the routing rules.**

```yaml
# Gateway — controls the listener
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: api-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        name: https
        protocol: HTTPS
      tls:
        mode: SIMPLE
        credentialName: api-tls-cert
      hosts:
        - "api.example.com"
        - "api.staging.example.com"
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "api.example.com"
      tls:
        httpsRedirect: true
---
# VirtualService — controls routing
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: api-routes
  namespace: default
spec:
  hosts:
    - "api.example.com"
  gateways:
    - istio-system/api-gateway
  http:
    - match:
        - uri:
            prefix: /api/v1/users
      route:
        - destination:
            host: users-svc.default.svc.cluster.local
            port:
              number: 8080
      timeout: 30s
      retries:
        attempts: 3
        perTryTimeout: 10s
        retryOn: 5xx,reset,connect-failure,retriable-4xx
    - match:
        - uri:
            prefix: /api/v1/orders
      route:
        - destination:
            host: orders-svc.default.svc.cluster.local
            port:
              number: 8080
      timeout: 15s
```

**Rules:**
- Gateway MUST be in `istio-system` namespace (or wherever the ingress gateway pod runs)
- VirtualService MUST reference the Gateway by fully qualified name (`namespace/name`)
- ALWAYS configure HTTP-to-HTTPS redirect on port 80 — never serve plain HTTP in production
- TLS certificates MUST be managed via `credentialName` referencing a Kubernetes Secret (use cert-manager)
- NEVER use `hosts: ["*"]` on Gateway — always specify exact hostnames
- VirtualService `hosts` MUST match Gateway `hosts` — mismatches silently drop traffic

## IST-02: Traffic Management — Routing Rules

### Header-Based Routing

```yaml
http:
  - match:
      - headers:
          x-api-version:
            exact: "v2"
        uri:
          prefix: /api/users
    route:
      - destination:
          host: users-svc-v2.default.svc.cluster.local
          port:
            number: 8080
  - match:
      - uri:
          prefix: /api/users
    route:
      - destination:
          host: users-svc-v1.default.svc.cluster.local
          port:
            number: 8080
```

### URI Rewriting

```yaml
http:
  - match:
      - uri:
          prefix: /api/v1/users
    rewrite:
      uri: /users
    route:
      - destination:
          host: users-svc.default.svc.cluster.local
```

### Request Mirroring (Shadow Traffic)

```yaml
http:
  - match:
      - uri:
          prefix: /api/v1/users
    route:
      - destination:
          host: users-svc-v1.default.svc.cluster.local
    mirror:
      host: users-svc-v2.default.svc.cluster.local
    mirrorPercentage:
      value: 10.0
```

**Rules:**
- Match rules are evaluated top-to-bottom — place more specific matches before general ones
- ALWAYS include a default route (no match conditions) as the last entry to catch unmatched traffic
- Mirror traffic is fire-and-forget — responses from the mirror are discarded
- Mirror percentage should start at 1-5% and ramp up gradually

## IST-03: Traffic Splitting and Canary Routing

**Weighted routing for gradual rollouts:**

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: users-canary
  namespace: default
spec:
  hosts:
    - users-svc.default.svc.cluster.local
  http:
    - route:
        - destination:
            host: users-svc.default.svc.cluster.local
            subset: stable
          weight: 90
        - destination:
            host: users-svc.default.svc.cluster.local
            subset: canary
          weight: 10
---
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: users-svc-subsets
  namespace: default
spec:
  host: users-svc.default.svc.cluster.local
  subsets:
    - name: stable
      labels:
        version: v1
    - name: canary
      labels:
        version: v2
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        h2UpgradePolicy: DEFAULT
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
```

**Canary rollout stages:**

| Stage | Canary Weight | Duration | Criteria to Advance |
|-------|:------------:|----------|---------------------|
| 1 | 1% | 15 minutes | No 5xx errors, p99 latency within 10% of baseline |
| 2 | 5% | 30 minutes | Error rate below 0.1%, no latency regression |
| 3 | 25% | 1 hour | Stable error rate, business metrics unchanged |
| 4 | 50% | 2 hours | Full validation, ready for promotion |
| 5 | 100% | — | Canary becomes stable, old version scaled down |

**Rules:**
- DestinationRule subsets MUST use pod labels that map to specific Deployment versions
- Weights MUST sum to 100 across all destinations in a route
- NEVER jump from 0% to 50% — follow the staged rollout table above
- Automate rollback: if error rate exceeds threshold at any stage, revert to 100% stable immediately
- Use Flagger or Argo Rollouts to automate the canary progression — never manually adjust weights in production

## IST-04: Fault Injection for Testing

### Delay Injection

```yaml
http:
  - fault:
      delay:
        percentage:
          value: 10.0
        fixedDelay: 3s
    match:
      - headers:
          x-test-fault:
            exact: "delay"
    route:
      - destination:
          host: users-svc.default.svc.cluster.local
```

### Abort Injection (HTTP Error)

```yaml
http:
  - fault:
      abort:
        percentage:
          value: 5.0
        httpStatus: 503
    match:
      - headers:
          x-test-fault:
            exact: "abort"
    route:
      - destination:
          host: users-svc.default.svc.cluster.local
```

**Rules:**
- Fault injection MUST be gated behind a header match (`x-test-fault`) — never inject faults unconditionally
- NEVER deploy fault injection rules to production — use only in staging and testing environments
- Use delay injection to validate timeout configurations and circuit breaker behavior
- Use abort injection to validate retry policies and fallback paths
- Fault injection percentage should start low (1%) and increase only for dedicated chaos testing sessions

## IST-05: Request Timeouts and Retries

```yaml
http:
  - route:
      - destination:
          host: users-svc.default.svc.cluster.local
    timeout: 30s
    retries:
      attempts: 3
      perTryTimeout: 10s
      retryOn: 5xx,reset,connect-failure,retriable-4xx
      retryRemoteLocalities: true
```

**Timeout guidelines:**

| Endpoint Type | Timeout | Per-Try Timeout | Retry Attempts |
|---------------|---------|-----------------|:--------------:|
| Read (GET) | 15s | 5s | 3 |
| Write (POST/PUT) | 30s | 10s | 1 (idempotent) or 0 (non-idempotent) |
| Long-running (reports) | 120s | 60s | 0 |
| Health check | 5s | 5s | 0 |

**Rules:**
- `timeout` MUST be greater than `perTryTimeout * attempts` to allow all retries to complete
- NEVER retry non-idempotent operations (`POST` without idempotency key) — it causes duplicate processing
- Use `retryOn: 5xx,reset,connect-failure` as the baseline — add `retriable-4xx` only for idempotent endpoints
- Set `retryRemoteLocalities: true` to retry on a different availability zone if the first attempt fails
- Circuit breaker (outlier detection in DestinationRule) MUST complement retries — retries without circuit breaking amplify failures

## IST-06: mTLS Enforcement

```yaml
# PeerAuthentication — enforce mTLS
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default
spec:
  mtls:
    mode: STRICT
---
# AuthorizationPolicy — control access
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: users-svc-policy
  namespace: default
spec:
  selector:
    matchLabels:
      app: users-svc
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - "cluster.local/ns/default/sa/api-gateway"
              - "cluster.local/ns/default/sa/orders-svc"
      to:
        - operation:
            methods: ["GET", "POST", "PUT", "DELETE"]
            paths: ["/users/*"]
```

**Rules:**
- PeerAuthentication MUST be `STRICT` in production — `PERMISSIVE` is only for migration periods
- Apply a mesh-wide `STRICT` PeerAuthentication in `istio-system` namespace, then override per-namespace only when needed
- AuthorizationPolicy MUST use allowlist (explicit `ALLOW`) — never rely on the default allow-all
- Use service account principals (`cluster.local/ns/<ns>/sa/<sa>`) for fine-grained access control
- NEVER use `source.namespaces` alone — it is too coarse; combine with `source.principals`
- Regularly audit AuthorizationPolicies to remove stale service account references

## Anti-Patterns (FORBIDDEN)

- Using `hosts: ["*"]` on Gateway resources in production
- Skipping HTTP-to-HTTPS redirect on port 80
- Deploying fault injection rules to production without header gating
- Retrying non-idempotent POST requests
- Setting PeerAuthentication to `PERMISSIVE` in production (except during migration)
- Using default allow-all AuthorizationPolicy — every service MUST have explicit policies
- Manually adjusting canary weights in production — use automated rollout controllers
- Setting timeouts without considering retry budget (`timeout < perTryTimeout * attempts`)
- Deploying VirtualService without a corresponding DestinationRule for subset-based routing
