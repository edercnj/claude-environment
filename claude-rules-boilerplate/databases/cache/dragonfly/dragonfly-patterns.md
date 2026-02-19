# Dragonfly — Patterns

## Overview

Dragonfly is a Redis-compatible in-memory data store built from scratch in C++ with a multi-threaded, shared-nothing architecture.

| Aspect | Detail |
|--------|--------|
| Version | 1.x stable |
| API compatibility | 100% Redis API (same client libraries) |
| Threading | Multi-threaded native (shared-nothing per core) |
| Memory | 25-40% less than Redis for same dataset |
| Throughput | Up to 25x Redis on multi-core (benchmarks vary) |
| Persistence | RDB + AOF (Redis-compatible snapshots) |
| Cluster mode | Built-in emulated cluster (no Sentinel needed) |
| License | BSL 1.1 (source-available) |

## Key Differences from Redis

| Feature | Redis | Dragonfly |
|---------|-------|-----------|
| Threading model | Single main thread + I/O threads | Multi-threaded shared-nothing |
| Memory overhead | ~50 bytes per key overhead | ~30 bytes per key overhead |
| Snapshot (BGSAVE) | Fork-based (2x memory spike) | Incremental, no fork, no memory spike |
| Max single-instance throughput | ~1M ops/sec | ~4M ops/sec (16 cores) |
| Cluster for scaling | Required for multi-core | Single instance uses all cores |
| Client libraries | All Redis clients | Same (drop-in replacement) |
| Lua scripting | Full support | Full support |
| Modules | Rich ecosystem | Limited compatibility |

## When to Prefer Dragonfly over Redis

| Scenario | Choose Dragonfly | Choose Redis |
|----------|-----------------|--------------|
| High throughput, single instance | Yes (multi-core native) | Need Cluster for multi-core |
| Memory-constrained environments | Yes (25-40% less RAM) | More RAM or accept overhead |
| Large datasets with snapshots | Yes (no fork, no 2x memory) | Need 2x memory headroom for BGSAVE |
| Existing Redis modules needed | No | Yes (module ecosystem) |
| Redis Cluster already deployed | Migration cost may not justify | Keep Redis |
| Managed service required | Limited options | AWS ElastiCache, Azure Cache, etc. |

## Configuration Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--proactor_threads` | Auto (# CPU cores) | Number of I/O threads |
| `--maxmemory` | 0 (unlimited) | Memory limit (e.g., `4gb`) |
| `--maxmemory_policy` | `noeviction` | Eviction policy (same options as Redis) |
| `--port` | 6379 | Listening port |
| `--dbfilename` | `dump` | RDB snapshot filename |
| `--dir` | `.` | Data directory |
| `--requirepass` | None | Authentication password |

### Minimal Production Configuration

```bash
dragonfly \
    --proactor_threads=8 \
    --maxmemory=4gb \
    --maxmemory_policy=allkeys-lru \
    --port=6379 \
    --dir=/data \
    --dbfilename=dump \
    --requirepass=${REDIS_PASSWORD}
```

## Framework Integration

Same as Redis. No code changes required.

```properties
# Quarkus — same config, just point to Dragonfly
quarkus.redis.hosts=redis://dragonfly-host:6379

# Spring Boot — same config
spring.data.redis.host=dragonfly-host
spring.data.redis.port=6379
```

## Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dragonfly
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: dragonfly
        image: docker.dragonflydb.io/dragonflydb/dragonfly:latest
        args:
        - --proactor_threads=4
        - --maxmemory=2gb
        - --maxmemory_policy=allkeys-lru
        ports:
        - containerPort: 6379
        resources:
          requests:
            memory: "2Gi"
            cpu: "4"
          limits:
            memory: "2.5Gi"
            cpu: "4"
```
