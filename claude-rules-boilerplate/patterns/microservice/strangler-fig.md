# Strangler Fig Pattern

## Intent

The Strangler Fig pattern enables incremental migration from a legacy monolith to a new architecture (typically microservices) by gradually replacing specific functionalities. Rather than a risky big-bang rewrite, new functionality is built in the new system while a routing layer progressively diverts traffic from legacy to new implementations. Over time, the legacy system is "strangled" as more features are migrated, until it can be decommissioned entirely.

## When to Use

- Migrating from monolith to microservices incrementally
- Legacy systems that cannot be rewritten all at once due to business continuity requirements
- When the legacy system is too large, too risky, or too poorly understood for a complete rewrite
- Organizations that need to deliver business value continuously during the migration
- When the migration timeline spans months or years

## When NOT to Use

- The legacy system is small enough for a clean rewrite in a few weeks
- The legacy system has no users and can be taken offline during migration
- When the routing and dual-running overhead exceeds the risk of a direct cutover
- When the target architecture is not meaningfully different from the source (refactor in place instead)
- Greenfield projects with no legacy to migrate from

## Structure

```
    ┌──────────────────────────────────────────────────────┐
    │                   Routing Layer                       │
    │              (Proxy / API Gateway)                    │
    │                                                      │
    │   Route A ──────────────────────► New Service A      │
    │   Route B ──────────────────────► New Service B      │
    │   Route C ──┐                                        │
    │   Route D ──┤                                        │
    │   Route E ──┴──────────────────► Legacy Monolith     │
    │                                                      │
    └──────────────────────────────────────────────────────┘

    Migration Timeline:
    ──────────────────────────────────────────────────────►

    Phase 1: [████░░░░░░] 20% migrated — Routes A, B in new system
    Phase 2: [██████░░░░] 60% migrated — Routes C, D extracted
    Phase 3: [██████████] 100% migrated — Legacy decommissioned
```

## Implementation Guidelines

### Migration Sequence

| Step | Action | Validation |
|------|--------|------------|
| 1. Introduce routing layer | Place a proxy/gateway in front of the monolith | All existing traffic flows through unchanged |
| 2. Identify migration candidate | Choose a bounded context with clear boundaries | Low coupling to other monolith components |
| 3. Build new implementation | Develop the feature in the new architecture | Passes all functional tests |
| 4. Shadow traffic | Route copies of production traffic to new system (results discarded) | Compare outputs for correctness |
| 5. Canary release | Route a small percentage of real traffic to new system | Monitor error rates, latency, correctness |
| 6. Gradual cutover | Increase traffic percentage to new system | Metrics stable at each increment |
| 7. Full cutover | Route 100% to new system | Legacy route disabled but reversible |
| 8. Decommission legacy route | Remove legacy code for this feature | After sufficient bake period |

### Candidate Selection Criteria

| Factor | Preferred | Risky |
|--------|-----------|-------|
| Coupling | Low coupling to other monolith components | Deeply entangled with shared state |
| Complexity | Well-understood business logic | Poorly documented, tribal knowledge only |
| Change frequency | Frequently changing (high ROI) | Stable, rarely modified (low ROI) |
| Data ownership | Clean data boundaries | Shared database tables across features |
| Team readiness | Team experienced with the domain | Domain expertise concentrated in one person |

### Routing Strategies

| Strategy | Mechanism | Granularity |
|----------|-----------|-------------|
| Path-based | Route by URL path prefix | Per feature/endpoint |
| Header-based | Route by custom header or user attribute | Per user segment |
| Percentage-based | Route N% to new, (100-N)% to legacy | Per request (random) |
| Feature toggle | Route based on feature flag per user/tenant | Per user or tenant |
| Geographic | Route based on client region | Per region |

### Data Migration Considerations

| Approach | Description | Risk |
|----------|-------------|------|
| Shared database | Both systems read/write the same database during transition | Schema coupling; migration blocked |
| Database per service | New service has its own database; data synchronized | Data consistency during transition |
| Event-driven sync | Legacy publishes events; new system consumes | Requires legacy modification |
| ETL/batch sync | Periodic data synchronization between stores | Staleness window |

**Guideline:** Start with a shared database if legacy modification is difficult. Migrate to separate databases per service as the boundary solidifies. The shared database is a transitional state, not the target.

### Parallel Running

Running both legacy and new implementations simultaneously to validate correctness:

| Aspect | Guideline |
|--------|-----------|
| Shadow mode | Send copies of requests to both; compare responses; only return legacy response |
| Verification | Automated comparison of legacy vs new responses; log discrepancies |
| Duration | Run parallel for at least one full business cycle (week, month) |
| Performance | Shadow traffic must not slow down the primary (legacy) response path |

### Rollback Strategy

- Every migration step MUST be reversible by routing traffic back to the legacy system
- Maintain the legacy implementation in a functional state until the new implementation is proven
- Feature toggles enable instant rollback without deployment
- Data written by the new system during canary MUST be reconcilable with legacy if rolled back

### Observability During Migration

| Metric | Purpose |
|--------|---------|
| Traffic split ratio | Percentage of requests going to legacy vs new |
| Error rate comparison | New system error rate vs legacy error rate per route |
| Latency comparison | P50, P95, P99 latency of new vs legacy per route |
| Data consistency | Discrepancies between legacy and new system outputs |
| Migration progress | Number of routes migrated vs remaining |

## Relationship to Other Patterns

- **API Gateway**: The gateway is the natural location for the routing layer that directs traffic between legacy and new systems
- **Anti-Corruption Layer**: New services MUST implement an ACL when consuming legacy APIs or data to prevent legacy models from leaking in
- **Service Discovery**: New services register with the discovery mechanism; the routing layer resolves their locations
- **Modular Monolith**: Often the intermediate step -- decompose the monolith into modules first, then extract modules into services
- **Feature Toggles**: Enable fine-grained control over which users or tenants are routed to the new system
