# Memcached — Patterns

## Overview

| Aspect | Detail |
|--------|--------|
| Version | 1.6.x stable |
| Data model | Key-value only (no data structures) |
| Threading | Multi-threaded native |
| Persistence | None (volatile cache only) |
| Max key size | 250 bytes |
| Max value size | 1 MB default (configurable) |
| Protocol | Text and binary (binary preferred) |
| Eviction | LRU per slab class |

## When to Use Memcached

| Scenario | Memcached | Redis/Dragonfly |
|----------|-----------|-----------------|
| Simple key-value caching | Yes | Overkill if only GET/SET |
| Need data structures | No | Yes |
| Need persistence | No | Yes |
| Need Pub/Sub | No | Yes |
| Multi-threaded by default | Yes | Redis: no / Dragonfly: yes |
| Extremely simple operations | Yes (lower overhead) | Higher overhead per operation |
| Large number of small values | Yes (slab allocator) | Acceptable |

## Slab Allocator

Memcached pre-allocates memory in **slab classes** of increasing sizes (64B, 128B, 256B, ...). Each value is stored in the smallest slab that fits.

| Slab Class | Size | Stores Values Up To |
|-----------|------|-------------------|
| 1 | 96 B | ~96 bytes |
| 2 | 120 B | ~120 bytes |
| 3 | 152 B | ~152 bytes |
| ... | ... | ... |
| N | 1 MB | 1 MB (max) |

**Implication:** A 65-byte value stored in a 96-byte slab wastes 31 bytes. Monitor slab utilization with `stats slabs`.

**Tuning:** `-f` flag controls growth factor (default 1.25). Lower factor = less waste, more slab classes.

## Configuration Flags

| Flag | Default | Description |
|------|---------|-------------|
| `-m` | 64 | Memory limit in MB |
| `-p` | 11211 | Listening port |
| `-c` | 1024 | Max simultaneous connections |
| `-t` | 4 | Number of threads |
| `-I` | 1m | Max item size (e.g., `5m` for 5MB) |
| `-f` | 1.25 | Slab growth factor |
| `-v` | — | Verbose logging |

```bash
memcached -m 512 -p 11211 -c 2048 -t 8 -I 2m -d
```

## Java Client Libraries

| Library | Status | Notes |
|---------|--------|-------|
| **spymemcached** | Maintenance mode | Widely used, async operations |
| **xmemcached** | Active | Better API, consistent hashing |
| **folsom** (Spotify) | Active | Async, Netty-based |

**No official Quarkus extension exists.** Use client libraries directly with CDI producer.

### CDI Producer (Quarkus/CDI)

```java
@ApplicationScoped
public class MemcachedProducer {

    @Produces
    @ApplicationScoped
    public MemcachedClient memcachedClient() throws IOException {
        return new XMemcachedClient("localhost", 11211);
    }

    public void close(@Disposes MemcachedClient client) throws IOException {
        client.shutdown();
    }
}
```

### Usage

```java
@ApplicationScoped
public class MerchantCache {

    private final MemcachedClient client;

    @Inject
    public MerchantCache(MemcachedClient client) {
        this.client = client;
    }

    public Optional<String> get(String mid) throws Exception {
        return Optional.ofNullable(client.get("simulator:merchant:" + mid));
    }

    public void set(String mid, String json, int ttlSeconds) throws Exception {
        client.set("simulator:merchant:" + mid, ttlSeconds, json);
    }

    public void invalidate(String mid) throws Exception {
        client.delete("simulator:merchant:" + mid);
    }
}
```

## Spring Boot Integration

```xml
<dependency>
    <groupId>com.google.code.simple-spring-memcached</groupId>
    <artifactId>spring-cache-starter</artifactId>
</dependency>
```

Or use `spring-boot-starter-cache` with a custom `CacheManager` backed by Memcached.

## Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Storing values > 1 MB | Rejected by default | Increase `-I` or split values |
| Keys > 250 bytes | Rejected | Hash long keys (SHA-256) |
| No monitoring | Slab waste undetected | Use `stats` and `stats slabs` |
| Using as primary data store | Data lost on restart | Memcached is cache only |
| Not setting expiry | Memory fills, LRU evicts unpredictably | Always set TTL |
| Assuming ordering | No guaranteed order | Memcached is unordered |
