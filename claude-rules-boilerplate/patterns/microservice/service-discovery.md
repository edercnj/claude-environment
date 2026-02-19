# Service Discovery

## Intent

Service Discovery solves the problem of locating service instances in a dynamic environment where instances are created, destroyed, and relocated continuously. Instead of hardcoding network addresses, services register themselves in a registry and discover each other at runtime. This enables elastic scaling, rolling deployments, and failure recovery without manual configuration changes.

## When to Use

- `architecture.style=microservice` where services need to locate each other dynamically
- Environments with auto-scaling where instance counts and addresses change frequently
- Kubernetes and container orchestration platforms (often built-in)
- When services are deployed across multiple hosts, zones, or regions
- Systems requiring zero-downtime deployments with rolling updates

## When NOT to Use

- Monolithic applications or modular monoliths deployed as a single unit
- Small systems with a fixed number of service instances behind a static load balancer
- When infrastructure-level service discovery (Kubernetes DNS) is sufficient and no application-level control is needed
- Environments where all services run on the same host

## Structure

### Server-Side Discovery

```
    Client ──► Load Balancer / Router ──► Service Registry
                      │                        │
                      │    ┌───────────────────┘
                      │    │ (resolve instances)
                      ▼    ▼
                ┌──────────────┐
                │  Instance A   │ ◄── registers
                │  Instance B   │ ◄── registers
                │  Instance C   │ ◄── registers
                └──────────────┘
```

### Client-Side Discovery

```
    Client ──► Service Registry ──► returns [Instance A, B, C]
       │
       │  (client-side load balancing)
       │
       ├──► Instance A
       ├──► Instance B
       └──► Instance C
```

### Comparison

| Aspect | Client-Side | Server-Side |
|--------|------------|-------------|
| Load balancing | Client decides | Router/LB decides |
| Client complexity | Higher (needs discovery logic) | Lower (just calls the router) |
| Network hops | Fewer (direct to instance) | One extra hop (through LB) |
| Language coupling | Client needs discovery library | Language-agnostic |
| Example tools | Eureka client, Consul client | Kubernetes Service, AWS ALB |
| Best for | Polyglot-tolerant teams | Platform-managed infrastructure |

## Implementation Guidelines

### Registration Approaches

| Approach | Mechanism | Responsibility |
|----------|-----------|---------------|
| Self-registration | Service registers itself on startup, heartbeats periodically | Service |
| Third-party registration | Platform agent or sidecar registers services | Infrastructure |
| Platform-native | Container orchestrator manages registration automatically | Platform (K8s, ECS) |

**Guideline:** Prefer platform-native registration when available. Self-registration is appropriate when running outside orchestrated environments.

### Health Check Integration

| Check Type | Purpose | Frequency | Failure Action |
|-----------|---------|-----------|----------------|
| Liveness | Is the process running? | Every 10-30s | Restart instance |
| Readiness | Can the instance serve traffic? | Every 5-15s | Remove from registry |
| Startup | Has the instance finished initializing? | During boot only | Wait before routing |
| Deep health | Are downstream dependencies accessible? | Every 30-60s | Mark degraded |

**Rules:**
- Liveness probes MUST be lightweight; they should never call external dependencies
- Readiness probes MAY check critical dependencies (database, cache)
- A failed readiness check MUST remove the instance from the discovery registry
- Recovery from readiness failure MUST re-register the instance automatically

### DNS-Based vs Registry-Based

| Aspect | DNS-Based | Registry-Based |
|--------|-----------|---------------|
| Resolution | DNS lookup (A/SRV records) | API call to registry |
| TTL sensitivity | Subject to DNS caching/TTL delays | Real-time updates |
| Metadata | Limited (SRV records for port/weight) | Rich (version, tags, health, zone) |
| Simplicity | Very simple; works everywhere | Requires registry infrastructure |
| Examples | Kubernetes DNS, Consul DNS | Eureka, Consul HTTP, etcd |

**Guideline:** Use DNS-based discovery as the baseline. Add registry-based discovery when you need metadata-aware routing, canary deployments, or real-time instance changes faster than DNS TTL allows.

### Instance Metadata

Services SHOULD register with metadata that enables intelligent routing:

| Metadata | Purpose |
|----------|---------|
| Service name | Logical service identifier |
| Instance ID | Unique instance identifier |
| Host and port | Network location |
| Version | Service version for canary routing |
| Zone / Region | Locality-aware routing |
| Weight | Traffic distribution preference |
| Health status | Current health state |
| Start time | Instance age for debugging |

### Failure Modes and Mitigations

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Registry unavailable | No new discoveries | Cache last-known instance list; retry with backoff |
| Stale registration | Traffic routed to dead instance | Short TTL + health checks; client-side retry |
| Split brain | Inconsistent views across clients | Consensus-based registry (etcd, Consul) |
| Thundering herd on recovery | All instances re-register simultaneously | Jittered registration delay |

## Relationship to Other Patterns

- **API Gateway**: The gateway uses service discovery to resolve backend service locations dynamically
- **Circuit Breaker**: When an instance is consistently failing, the circuit breaker opens; combine with discovery to route away from unhealthy instances
- **Bulkhead**: Discovery metadata (zone, version) enables routing decisions that support bulkhead isolation
- **Retry with Backoff**: On connection failure to a discovered instance, retry with a different instance from the registry
- **Strangler Fig**: Service discovery enables gradual migration by routing traffic percentages to old vs new implementations
