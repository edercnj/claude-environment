# Cache Principles

## Decision Matrix: Redis vs Dragonfly vs Memcached

| Criterion | Redis | Dragonfly | Memcached |
|-----------|-------|-----------|-----------|
| Data structures | Rich (strings, hashes, lists, sets, sorted sets, streams) | Same as Redis (API compatible) | Key-value only |
| Threading | Single-threaded (+ I/O threads 6.0+) | Multi-threaded native | Multi-threaded native |
| Persistence | RDB + AOF | RDB + AOF (compatible) | None |
| Memory efficiency | Good | 25-40% less than Redis | Good (slab allocator) |
| Pub/Sub | Yes | Yes | No |
| Lua scripting | Yes | Yes | No |
| Cluster mode | Redis Cluster / Sentinel | Built-in (no Sentinel needed) | Client-side sharding |
| Max value size | 512 MB | 512 MB | 1 MB default |
| Maturity | Very high | Growing | Very high |
| Use case | General purpose cache + data store | Redis replacement with better performance | Simple key-value cache |

## Cache Patterns

| Pattern | Description | Write Path | Read Path | Consistency | Use Case |
|---------|-------------|------------|-----------|-------------|----------|
| **Cache-Aside** | App manages cache explicitly | App writes to DB; invalidates cache | App reads cache; on miss reads DB and populates cache | Eventual | Most common; general purpose |
| **Read-Through** | Cache loads from DB on miss | App writes to DB; cache auto-loads | Cache returns data; loads from DB on miss | Eventual | Simplified read logic |
| **Write-Through** | Cache writes to DB synchronously | App writes to cache; cache writes to DB | App reads from cache | Strong | Data must not be lost |
| **Write-Behind** | Cache writes to DB asynchronously | App writes to cache; cache queues DB write | App reads from cache | Eventual | High write throughput |

**Default choice:** Cache-Aside. Use Write-Through only when cache must always reflect DB state.

## Key Naming Convention

```
{service}:{entity}:{id}:{field}
```

| Example | Purpose |
|---------|---------|
| `simulator:merchant:MID123:profile` | Merchant profile |
| `simulator:merchant:MID123:terminals` | Merchant terminal list |
| `simulator:tx:STAN456:result` | Transaction result |
| `simulator:config:rate-limit:tcp` | Rate limit config |
| `simulator:session:abc123` | User session |

**Rules:**
- Colon (`:`) as separator
- Lowercase service and entity names
- No spaces, no special characters in keys
- Keep keys under 128 bytes

## TTL Strategy

| Data Type | TTL | Reason |
|-----------|-----|--------|
| Session data | 30 min - 24h | Security, memory |
| API response cache | 1 - 5 min | Freshness |
| User profile | 15 - 60 min | Low change frequency |
| Configuration | 5 - 15 min | Infrequent updates |
| Rate limit counters | 1 - 60 sec | Rolling window |
| Transaction result | 5 - 30 min | Lookup for reversals |
| Static reference data | 1 - 24h | Rarely changes |
| Computed aggregates | 5 - 60 min | Expensive to recalculate |

**Rule:** Every cache entry MUST have a TTL. No TTL = memory leak.

## Serialization

| Format | Speed | Size | Schema Evolution | Use Case |
|--------|-------|------|-----------------|----------|
| **JSON** | Good | Larger | Easy (add fields) | Default choice, debugging friendly |
| **Protobuf** | Fast | Compact | Good (field numbers) | High-throughput, inter-service |
| **MessagePack** | Fast | Compact | Moderate | Binary JSON alternative |
| **Java Serialization** | Slow | Large | Poor | **PROHIBITED** (security + size) |

**Rule:** Use JSON for general caching. Use Protobuf when throughput > 10K ops/sec on cache.

## Thundering Herd Prevention

When a popular cache key expires, many threads simultaneously hit the database.

| Strategy | Description | Complexity |
|----------|-------------|-----------|
| **Mutex/Lock** | First thread acquires lock, others wait | Low |
| **Stale-while-revalidate** | Serve stale data while refreshing in background | Medium |
| **Probabilistic early expiration** | Randomly refresh before TTL expires | Medium |
| **Pre-warming** | Populate cache before expected traffic spike | Low |

```java
// Mutex approach (simplified)
public Optional<T> getWithMutex(String key, Supplier<T> loader) {
    var cached = cache.get(key);
    if (cached != null) return Optional.of(cached);

    if (lock.tryLock(key, 5, TimeUnit.SECONDS)) {
        try {
            cached = cache.get(key);  // Double-check
            if (cached != null) return Optional.of(cached);
            var value = loader.get();
            cache.set(key, value, ttl);
            return Optional.of(value);
        } finally {
            lock.unlock(key);
        }
    }
    return Optional.empty();  // Return empty rather than stampede
}
```

## Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| No TTL | Memory grows unbounded, stale data | Always set TTL |
| Caching sensitive data (PAN, PIN) | Security risk | Never cache PROHIBITED data |
| Unbounded cache | OOM | Set maxmemory + eviction policy |
| Cache as primary store | Data loss on restart | Cache is ephemeral; DB is source of truth |
| Large values (> 1 MB) | Latency, memory fragmentation | Split or compress |
| Hot key (single key, extreme traffic) | Single-node bottleneck | Replicate key with random suffix |
| No metrics | Cannot diagnose issues | Track hit ratio, latency, evictions |

## Mandatory Metrics

| Metric | Type | Alert Threshold |
|--------|------|----------------|
| `cache.hit_ratio` | Gauge | < 80% (investigate) |
| `cache.miss_count` | Counter | Sudden spike |
| `cache.latency_p99` | Histogram | > 10ms |
| `cache.evictions` | Counter | Sustained high rate |
| `cache.connections.active` | Gauge | Near pool max |
| `cache.memory.used_bytes` | Gauge | > 80% maxmemory |
