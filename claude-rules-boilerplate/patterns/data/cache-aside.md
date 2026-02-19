# Cache-Aside Pattern

## Intent

The Cache-Aside pattern (also called Lazy Loading) places the application in control of cache population and invalidation. The application checks the cache before querying the database; on a cache miss, it loads from the database, populates the cache, and returns the result. On writes, the application updates the database and invalidates or updates the cache. This explicit control avoids the complexity of transparent caching while giving the application full authority over cache behavior, TTLs, and invalidation strategies.

## When to Use

- Read-heavy workloads where the same data is requested frequently
- When eventual consistency between cache and database is acceptable
- Applications where cache misses should transparently fall back to the database
- Systems with predictable hot data that benefits from caching
- Reference: `databases/cache/common/cache-principles.md` provides the cache strategy foundation

## When NOT to Use

- Write-heavy workloads where cached data would be invalidated faster than it is read
- When strong consistency between cache and database is required on every read
- Data that changes too frequently for any TTL to be useful (sub-second change frequency)
- When the working set is too large to fit in the cache (low hit ratio, wasted resources)
- Single-use data that is unlikely to be requested again within the TTL window

## Structure

```
    READ PATH (Cache Hit):
    Client ──► Application ──► Cache ──► Return cached data
                                  │
                              [HIT] ✓

    READ PATH (Cache Miss):
    Client ──► Application ──► Cache ──► [MISS]
                   │                        │
                   │               ┌────────┘
                   ▼               │
               Database ◄─────────┘
                   │
                   ├──► Return data to Application
                   │
                   └──► Application writes to Cache (populate)
                              │
                              ▼
                        Return data to Client

    WRITE PATH:
    Client ──► Application ──► Database (write)
                   │
                   └──► Cache (invalidate or update)
```

## Implementation Guidelines

### Cache Population Strategy

| Strategy | Mechanism | Consistency | Complexity |
|----------|-----------|-------------|------------|
| Cache-Aside (lazy) | Populate on miss; invalidate on write | Eventual | Low |
| Read-Through | Cache auto-loads from DB on miss | Eventual | Medium (requires cache-DB integration) |
| Write-Through | Write to cache and DB synchronously | Strong | Medium |
| Write-Behind | Write to cache; async flush to DB | Eventual (risk of data loss) | High |
| Refresh-Ahead | Proactively refresh before TTL expires | Eventual (fresher) | Medium |

**Default choice:** Cache-Aside. It is the simplest, most widely applicable, and gives the application full control.

### Cache Invalidation Strategies

| Strategy | Mechanism | When to Use |
|----------|-----------|-------------|
| TTL expiration | Cached entry expires after a fixed duration | Default for all cached data |
| Explicit invalidation | Application deletes cache key on write | When writes are infrequent and cache must reflect changes quickly |
| Event-driven invalidation | Listen for domain events and invalidate affected keys | Multi-instance deployments where local cache must sync |
| Version-based | Include a version in the cache key; increment on write | When partial invalidation is complex |

**Rule:** Every cache entry MUST have a TTL, even if explicit invalidation is also used. TTL is the safety net against stale data when invalidation fails.

### TTL Guidelines

| Data Type | TTL Range | Rationale |
|-----------|-----------|-----------|
| Session data | 30 min - 24h | Security and memory |
| API response cache | 1-5 min | Freshness for API consumers |
| User profiles | 15-60 min | Low change frequency |
| Configuration | 5-15 min | Infrequent updates |
| Rate limit counters | 1-60 sec | Rolling window accuracy |
| Static reference data | 1-24h | Rarely changes |
| Computed aggregates | 5-60 min | Expensive to recompute |

### Thundering Herd Prevention

When a popular cache key expires, many concurrent requests simultaneously miss and hit the database.

| Strategy | Mechanism | Trade-off |
|----------|-----------|-----------|
| Mutex/lock | First requester acquires a lock; others wait | Simple; adds latency for waiters |
| Stale-while-revalidate | Serve expired data while refreshing in background | Complex; requires background refresh capability |
| Probabilistic early expiration | Randomly refresh before TTL (beta * ln(random) approach) | Distributed; no coordination needed |
| Pre-warming | Populate cache before expected traffic | Requires knowledge of traffic patterns |

### Write-Path Consistency

| Approach | Operation Order | Risk |
|----------|----------------|------|
| Invalidate cache, then write DB | Cache miss between invalidate and DB commit | Brief window of DB query (low risk) |
| Write DB, then invalidate cache | Stale data served between DB commit and invalidation | Brief staleness window (usually acceptable) |
| Write DB, then update cache | Cache updated with latest data | Concurrent writes can leave cache with older value |

**Guideline:** Prefer "write DB, then invalidate cache." It is the simplest and safest for most applications. The staleness window is typically milliseconds. Avoid updating the cache with the new value on write, as concurrent writes can race.

### Cache Key Design

| Principle | Guideline |
|-----------|-----------|
| Namespace | Prefix with service and entity: `{service}:{entity}:{id}` |
| Determinism | Same input always produces the same key |
| Uniqueness | Include all parameters that affect the cached value |
| Size | Keep keys under 128 bytes |
| Versioning | Include a version prefix if the cached data format changes |

### Monitoring Requirements

| Metric | Type | Alert Threshold |
|--------|------|----------------|
| Hit ratio | Gauge | Below 80% (investigate cache sizing or TTL) |
| Miss count | Counter | Sudden spike indicates invalidation storm or new traffic pattern |
| Latency P99 | Histogram | Above 10ms (cache should be fast) |
| Evictions | Counter | Sustained high rate indicates undersized cache |
| Memory usage | Gauge | Above 80% of allocated maximum |

### Anti-Patterns

| Anti-Pattern | Problem | Solution |
|-------------|---------|----------|
| No TTL | Memory leak; stale data indefinitely | Every entry MUST have a TTL |
| Cache as primary store | Data loss on cache restart | Database is always source of truth |
| Caching sensitive data | Security risk on cache compromise | Never cache PII, credentials, secrets |
| Large cached values (> 1 MB) | Latency, fragmentation | Split or compress large values |
| Hot key (single key, extreme traffic) | Single-node bottleneck | Replicate with randomized suffixes |
| Unbounded cache | Out of memory | Set max memory and eviction policy |

## Relationship to Other Patterns

- **Reference**: `databases/cache/common/cache-principles.md` defines cache strategies, key naming, TTL, and serialization guidelines
- **Repository Pattern**: The repository implementation may incorporate cache-aside internally, transparent to the domain
- **CQRS**: Read-side projections often use caching; cache-aside is the natural pattern for query-side caching
- **Circuit Breaker**: If the cache is unavailable, the application falls through to the database; a circuit breaker can protect against a failing cache layer
- **Bulkhead**: Separate cache connection pools from database connection pools to prevent cache failures from exhausting DB connections
