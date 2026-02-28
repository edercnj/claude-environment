# Redis — Patterns

## Version Matrix

| Version | Key Features |
|---------|-------------|
| **7.0** | Redis Functions (Lua replacement), ACL v2, sharded Pub/Sub, multi-part AOF |
| **7.2** | Client-side caching improvements, `WAITAOF`, stream consumer auto-claiming |
| **7.4** | Hash field expiration, performance improvements, improved memory efficiency |

## Data Structures — When to Use

| Structure | Commands | Use Case | Max Size |
|-----------|----------|----------|----------|
| **STRING** | `GET`, `SET`, `INCR`, `MGET` | Simple cache, counters, locks | 512 MB |
| **HASH** | `HGET`, `HSET`, `HGETALL`, `HINCRBY` | Object storage (user profile, config) | 2^32 fields |
| **LIST** | `LPUSH`, `RPOP`, `LRANGE`, `LLEN` | Queues, recent items, activity feed | 2^32 elements |
| **SET** | `SADD`, `SMEMBERS`, `SINTER`, `SCARD` | Tags, unique visitors, set operations | 2^32 members |
| **SORTED SET** | `ZADD`, `ZRANGE`, `ZRANGEBYSCORE`, `ZRANK` | Leaderboards, rate limiters, priority queues | 2^32 members |
| **STREAM** | `XADD`, `XREAD`, `XREADGROUP`, `XACK` | Event log, message broker, audit trail | Configurable |
| **BITMAP** | `SETBIT`, `GETBIT`, `BITCOUNT` | Feature flags, daily active users | 512 MB |
| **HyperLogLog** | `PFADD`, `PFCOUNT`, `PFMERGE` | Cardinality estimation (unique counts) | 12 KB fixed |

### Decision Quick Reference

| Need | Use |
|------|-----|
| Cache a JSON object | `STRING` (serialized) or `HASH` (field-level access) |
| Count events | `STRING` with `INCR` |
| Task queue | `LIST` (LPUSH/RPOP) or `STREAM` (with consumer groups) |
| Unique set membership | `SET` |
| Ranked items | `SORTED SET` |
| Event sourcing | `STREAM` |

## Cluster vs Sentinel

| Aspect | Redis Sentinel | Redis Cluster |
|--------|---------------|---------------|
| Purpose | High availability (failover) | HA + horizontal scaling |
| Sharding | No (single master) | Yes (16384 hash slots) |
| Max data size | Single node memory | Sum of all nodes |
| Multi-key operations | All keys available | Only within same hash slot |
| Complexity | Low | Medium |
| Use when | Data fits in one node | Data exceeds single node memory |

**Rule:** Start with Sentinel. Move to Cluster only when single-node memory is insufficient.

## Pub/Sub Patterns

| Pattern | Use Case | Delivery Guarantee |
|---------|----------|--------------------|
| `PUBLISH` / `SUBSCRIBE` | Real-time notifications, cache invalidation | At-most-once (fire and forget) |
| Sharded Pub/Sub (7.0+) | High-throughput channels in Cluster mode | At-most-once |
| Streams + Consumer Groups | Reliable message processing | At-least-once (with `XACK`) |

**Rule:** Use Streams with consumer groups when messages must not be lost. Use Pub/Sub only for notifications where loss is acceptable.

## Lua Scripting

Execute atomic operations server-side. All commands in a script run without interleaving.

```lua
-- Rate limiter: token bucket (atomic)
local key = KEYS[1]
local max_tokens = tonumber(ARGV[1])
local refill_rate = tonumber(ARGV[2])
local now = tonumber(ARGV[3])

local bucket = redis.call('HMGET', key, 'tokens', 'last_refill')
local tokens = tonumber(bucket[1]) or max_tokens
local last_refill = tonumber(bucket[2]) or now

local elapsed = now - last_refill
local new_tokens = math.min(max_tokens, tokens + elapsed * refill_rate)

if new_tokens >= 1 then
    redis.call('HMSET', key, 'tokens', new_tokens - 1, 'last_refill', now)
    redis.call('EXPIRE', key, 60)
    return 1  -- allowed
else
    redis.call('HMSET', key, 'tokens', new_tokens, 'last_refill', now)
    redis.call('EXPIRE', key, 60)
    return 0  -- rejected
end
```

**7.0+ note:** Redis Functions (`FUNCTION LOAD`) replace `EVAL`-based Lua scripts for better lifecycle management.

## Framework Integration

### Quarkus

**Extension:** `quarkus-redis`

```java
@ApplicationScoped
public class MerchantCacheAdapter {

    private final RedisDataSource redis;

    @Inject
    public MerchantCacheAdapter(RedisDataSource redis) {
        this.redis = redis;
    }

    public Optional<String> getCachedMerchant(String mid) {
        return Optional.ofNullable(
            redis.value(String.class).get("simulator:merchant:" + mid + ":profile"));
    }

    public void cacheMerchant(String mid, String json, Duration ttl) {
        redis.value(String.class).setex("simulator:merchant:" + mid + ":profile", ttl.getSeconds(), json);
    }

    public void invalidate(String mid) {
        redis.key().del("simulator:merchant:" + mid + ":profile");
    }
}
```

**Quarkus Cache annotation (quarkus-cache + redis backend):**

```java
@CacheResult(cacheName = "merchants")
public MerchantResponse findMerchant(String mid) { /* DB lookup */ }

@CacheInvalidate(cacheName = "merchants")
public void updateMerchant(String mid, UpdateRequest request) { /* DB update */ }
```

### Spring Boot

**Dependency:** `spring-boot-starter-data-redis`

```java
@Cacheable(value = "merchants", key = "#mid")
public MerchantResponse findMerchant(String mid) { /* DB lookup */ }

@CacheEvict(value = "merchants", key = "#mid")
public void updateMerchant(String mid, UpdateRequest request) { /* DB update */ }
```

## Configuration

```properties
# Quarkus
quarkus.redis.hosts=redis://localhost:6379
quarkus.redis.max-pool-size=8
quarkus.redis.max-pool-waiting=16
quarkus.redis.timeout=5s

# Spring Boot
spring.data.redis.host=localhost
spring.data.redis.port=6379
spring.data.redis.lettuce.pool.max-active=8
spring.data.redis.lettuce.pool.max-wait=5s
spring.data.redis.timeout=5s
```

## Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| `KEYS *` in production | Blocks server, O(N) | Use `SCAN` iterator |
| Large values (> 1 MB) | Network latency, fragmentation | Split or compress |
| No eviction policy | OOM crash | Set `maxmemory-policy allkeys-lru` |
| Storing sessions without TTL | Memory leak | Always set expiry |
| `FLUSHALL` in production | Data loss | Use targeted `DEL` or `UNLINK` |
| Blocking commands on event loop | Blocks all clients | Use dedicated connection or async |
