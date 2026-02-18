# Language Profiles

This document contains built-in profiles for supported languages and frameworks.
Each profile provides the numeric constants needed by the capacity calculation formulas
in SKILL.md. When the detected language/framework matches a profile below, use its
values directly. For unlisted frameworks, use the language-level defaults and adjust
based on framework documentation.

## Table of Contents

1. [Java](#java)
2. [Go](#go)
3. [Python](#python)
4. [TypeScript / Node.js](#typescript--nodejs)
5. [Rust](#rust)
6. [Database Type Sizes](#database-type-sizes)

---

## Java

### Runtime Variants

| Variant | Base Overhead (MB) | Notes |
|---|---|---|
| JVM (OpenJDK 21) | 150-250 | Depends on heap settings, class loading |
| GraalVM Native | 30-60 | Ahead-of-time compiled, minimal runtime |

### Framework Overhead

| Framework | Additional Base (MB) | Default Thread Pool | Typical Stack Size |
|---|---|---|---|
| Quarkus (JVM) | +80 | 200 (Vert.x event loop + worker pool) | 1MB |
| Quarkus (Native) | +10 | 200 | 256KB |
| Spring Boot | +120 | 200 (Tomcat default) | 1MB |
| Spring Boot (WebFlux) | +100 | cores × 2 (Netty event loops) | 1MB |
| Micronaut | +60 | 200 (Netty) | 1MB |
| Jakarta EE (WildFly) | +200 | 300 | 1MB |

### Per-Request Memory

| Request Type | Heap Allocation (KB) | Notes |
|---|---|---|
| Simple REST CRUD | 50-100 | Small DTO serialization |
| Complex business logic | 100-300 | Multiple object creation |
| File upload/processing | 500-5000 | Depends on file size |
| Report generation | 1000-10000 | Large buffer allocations |
| Streaming response | 50-200 | Backpressure-controlled |

### Connection Pool Memory

| Pool Type | Per Connection (MB) | Typical Default Size |
|---|---|---|
| HikariCP (PostgreSQL) | 1.0-2.0 | 10 |
| HikariCP (MySQL) | 0.8-1.5 | 10 |
| Agroal (Quarkus default) | 0.8-1.5 | 20 |
| Redis (Lettuce) | 0.5-1.0 | 8 |
| Redis (Jedis) | 1.0-2.0 | 8 |
| HTTP Client (JDK) | 0.3-0.5 | 5 per host |
| Kafka Producer | 32.0 (buffer.memory default) | 1 |
| Kafka Consumer | 50.0 (fetch buffers) | 1 per partition |

### GC Characteristics

| GC Algorithm | Headroom Factor | CPU Overhead | Pause Characteristics |
|---|---|---|---|
| G1GC (default JDK 21) | 0.50 | 8-12% | Short pauses, predictable |
| ZGC | 0.30 | 3-5% | Sub-millisecond pauses |
| Shenandoah | 0.30 | 5-8% | Low pause, concurrent |
| Serial GC | 0.40 | 2-3% | Long pauses, stop-the-world |
| Parallel GC | 0.45 | 5-10% | Throughput optimized |

### CPU Throughput Baseline

| Operation Type | Requests/sec/core | Notes |
|---|---|---|
| Simple REST (JSON CRUD) | 1500-2500 | Quarkus/Spring typical |
| Complex business logic | 500-1000 | Multiple service calls |
| Database-heavy (5+ queries) | 300-800 | I/O bound |
| File processing | 50-200 | CPU bound |
| Native image (Quarkus) | 2000-3500 | Faster startup, similar throughput |

### Java Type Sizes (for DB row estimation)

| Java Type | Typical DB Column | Bytes |
|---|---|---|
| `String` (short, <50 chars) | VARCHAR(50) | 50 |
| `String` (medium, <255 chars) | VARCHAR(255) | 255 |
| `String` (long) | TEXT | 1000 (avg estimate) |
| `int` / `Integer` | INTEGER | 4 |
| `long` / `Long` | BIGINT | 8 |
| `BigDecimal` | DECIMAL/NUMERIC | 16 |
| `boolean` / `Boolean` | BOOLEAN | 1 |
| `LocalDateTime` | TIMESTAMP | 8 |
| `OffsetDateTime` | TIMESTAMPTZ | 12 |
| `UUID` | UUID/VARCHAR(36) | 16 |
| `byte[]` | BYTEA/BLOB | variable |
| `enum` | VARCHAR(20) | 20 |

---

## Go

### Runtime

| Metric | Value | Notes |
|---|---|---|
| Base Overhead | 5-15 MB | Minimal runtime, no VM |
| Goroutine Stack (initial) | 8 KB | Grows dynamically up to 1GB |
| Goroutine Stack (typical) | 8-64 KB | Depends on call depth |
| Max Goroutines (practical) | 100K-1M | Limited by memory |

### Framework Overhead

| Framework | Additional Base (MB) | Default Concurrency | Notes |
|---|---|---|---|
| Standard library (net/http) | +2 | Unlimited goroutines | One goroutine per request |
| Gin | +3 | Unlimited goroutines | Lightweight wrapper |
| Echo | +3 | Unlimited goroutines | Similar to Gin |
| Fiber | +5 | Prefork workers | Fasthttp-based |
| gRPC-Go | +10 | Configurable | Streaming support |

### Per-Request Memory

| Request Type | Allocation (KB) | Notes |
|---|---|---|
| Simple REST CRUD | 10-30 | Minimal allocations |
| Complex business logic | 30-100 | More object creation |
| File processing | 100-5000 | Buffer allocations |
| gRPC streaming | 20-50 | Per-stream buffers |

### Connection Pool Memory

| Pool Type | Per Connection (MB) | Typical Default |
|---|---|---|
| database/sql (PostgreSQL) | 0.5-1.0 | 0 (unlimited) |
| database/sql (MySQL) | 0.5-1.0 | 0 (unlimited) |
| go-redis | 0.3-0.5 | 10 |
| HTTP client (default) | 0.2-0.5 | 100 per host |
| Kafka (sarama) | 10.0 | 1 per broker |

### GC Characteristics

| Metric | Value |
|---|---|
| GC Algorithm | Concurrent Mark-Sweep |
| Headroom Factor | 0.25 |
| CPU Overhead | 3-5% |
| GOGC Default | 100 (GC at 2× live heap) |
| Typical Pause | <1ms |

### CPU Throughput Baseline

| Operation Type | Requests/sec/core |
|---|---|
| Simple REST (JSON CRUD) | 4000-6000 |
| Complex business logic | 1500-3000 |
| Database-heavy | 800-2000 |
| File/stream processing | 200-500 |

### Go Type Sizes

| Go Type | Typical DB Column | Bytes |
|---|---|---|
| `string` (short) | VARCHAR(50) | 50 |
| `string` (medium) | VARCHAR(255) | 255 |
| `int32` | INTEGER | 4 |
| `int64` | BIGINT | 8 |
| `float64` | DOUBLE | 8 |
| `bool` | BOOLEAN | 1 |
| `time.Time` | TIMESTAMPTZ | 12 |
| `uuid.UUID` | UUID | 16 |
| `[]byte` | BYTEA | variable |

---

## Python

### Runtime

| Metric | Value | Notes |
|---|---|---|
| Base Overhead (CPython) | 30-50 MB | Interpreter + imported modules |
| Base Overhead (PyPy) | 60-80 MB | JIT compiler adds overhead |
| Per-Thread Stack | 8 MB (default) | Can be reduced with threading.stack_size() |
| GIL Impact | Single-threaded CPU | Only 1 thread executes Python at a time |

### Framework Overhead

| Framework | Additional Base (MB) | Default Workers | Concurrency Model |
|---|---|---|---|
| Django + Gunicorn | +80 per worker | 2×cores+1 workers | Process-based |
| FastAPI + Uvicorn | +40 per worker | 1 worker (default) | Async event loop |
| Flask + Gunicorn | +50 per worker | 2×cores+1 workers | Process-based |
| Celery Worker | +60 per worker | cores workers | Process/thread pool |

### Per-Request Memory

| Request Type | Allocation (KB) | Notes |
|---|---|---|
| Simple REST CRUD | 30-80 | Django ORM overhead |
| Complex business logic | 80-300 | Python object overhead is high |
| Data processing (Pandas) | 500-50000 | DataFrame in memory |
| ML inference | 1000-100000 | Model + input + output |

### Connection Pool Memory

| Pool Type | Per Connection (MB) | Typical Default |
|---|---|---|
| psycopg2 (PostgreSQL) | 1.0-2.0 | 5 |
| SQLAlchemy pool | 1.0-2.0 | 5 |
| redis-py | 0.5-1.0 | 10 |
| aiohttp client | 0.3-0.5 | 100 |
| Celery broker (Redis) | 2.0 | 1 per worker |

### GC Characteristics

| Metric | Value |
|---|---|
| GC Algorithm | Reference counting + cyclic GC |
| Headroom Factor | 0.15 |
| CPU Overhead | 2-5% |
| Note | Multi-worker = multi-process, each has own memory |

### CPU Throughput Baseline

| Operation Type | Requests/sec/core |
|---|---|
| Simple REST (JSON CRUD) | 500-1500 |
| Complex business logic | 200-500 |
| Database-heavy | 100-400 |
| Data processing | 10-100 |
| Async I/O (FastAPI) | 1000-3000 |

### Python Type Sizes

| Python Type | Typical DB Column | Bytes |
|---|---|---|
| `str` (short) | VARCHAR(50) | 50 |
| `str` (medium) | VARCHAR(255) | 255 |
| `int` | INTEGER/BIGINT | 4-8 |
| `float` | DOUBLE | 8 |
| `Decimal` | DECIMAL | 16 |
| `bool` | BOOLEAN | 1 |
| `datetime` | TIMESTAMPTZ | 12 |
| `uuid.UUID` | UUID | 16 |
| `bytes` | BYTEA | variable |

---

## TypeScript / Node.js

### Runtime

| Metric | Value | Notes |
|---|---|---|
| Base Overhead (Node.js) | 40-60 MB | V8 engine + core modules |
| V8 Heap Limit (default) | ~1.5 GB | Can be increased with --max-old-space-size |
| Event Loop | Single-threaded | Non-blocking I/O |
| Worker Threads (libuv) | 4 (default) | For file I/O, DNS, crypto |

### Framework Overhead

| Framework | Additional Base (MB) | Default Concurrency | Notes |
|---|---|---|---|
| Express | +15 | Event loop (single) | Most popular, middleware-heavy |
| Fastify | +10 | Event loop (single) | Schema-based validation, faster |
| NestJS | +30 | Event loop (single) | Decorator-heavy, more memory |
| Next.js (API routes) | +80 | Event loop (single) | SSR adds overhead |
| PM2 (cluster mode) | +50 per instance | N instances | One per CPU core |

### Per-Request Memory

| Request Type | Allocation (KB) | Notes |
|---|---|---|
| Simple REST CRUD | 20-50 | Small JSON parsing |
| Complex business logic | 50-200 | Object creation, closures |
| File upload/processing | 200-5000 | Buffer allocations |
| SSR (React/Next) | 500-2000 | Component tree rendering |

### Connection Pool Memory

| Pool Type | Per Connection (MB) | Typical Default |
|---|---|---|
| pg (node-postgres) | 0.5-1.0 | 10 |
| mysql2 | 0.5-1.0 | 10 |
| ioredis | 0.3-0.5 | 1 |
| axios/fetch pool | 0.2-0.3 | Infinity (per host) |
| Prisma connection pool | 0.5-1.0 | num_cpus × 2 + 1 |

### GC Characteristics

| Metric | Value |
|---|---|
| GC Algorithm | V8 Generational (Scavenge + Mark-Sweep) |
| Headroom Factor | 0.30 |
| CPU Overhead | 3-8% |
| Pause | 1-10ms (incremental marking) |
| Note | Large heaps (>1GB) can cause longer pauses |

### CPU Throughput Baseline

| Operation Type | Requests/sec/core |
|---|---|
| Simple REST (JSON CRUD) | 2000-4000 |
| Complex business logic | 800-1500 |
| Database-heavy | 500-1500 |
| SSR rendering | 50-200 |
| Pure computation (no async) | 300-800 |

### TypeScript Type Sizes

| TS Type | Typical DB Column | Bytes |
|---|---|---|
| `string` (short) | VARCHAR(50) | 50 |
| `string` (medium) | VARCHAR(255) | 255 |
| `number` (integer) | INTEGER | 4 |
| `number` (float) | DOUBLE | 8 |
| `boolean` | BOOLEAN | 1 |
| `Date` | TIMESTAMPTZ | 12 |
| `string` (UUID) | UUID/VARCHAR(36) | 16-36 |
| `Buffer` | BYTEA | variable |

---

## Rust

### Runtime

| Metric | Value | Notes |
|---|---|---|
| Base Overhead | 2-8 MB | No runtime, no GC |
| Thread Stack (default) | 8 MB | Configurable per thread |
| Async Task Size | 1-10 KB | Depends on future state |
| Max Concurrent Tasks | Millions | Limited only by memory |

### Framework Overhead

| Framework | Additional Base (MB) | Default Concurrency | Notes |
|---|---|---|---|
| Actix-web | +3 | cores × 2 workers | Multi-threaded runtime |
| Axum (Tokio) | +2 | cores workers | Async runtime |
| Rocket | +5 | cores × 2 workers | Sync + async support |
| Warp | +2 | Tokio runtime | Filter-based |

### Per-Request Memory

| Request Type | Allocation (KB) | Notes |
|---|---|---|
| Simple REST CRUD | 5-20 | Minimal heap allocation |
| Complex business logic | 20-50 | Stack-allocated where possible |
| File processing | 50-2000 | Buffer allocations |
| Streaming | 5-20 | Zero-copy capable |

### Connection Pool Memory

| Pool Type | Per Connection (MB) | Typical Default |
|---|---|---|
| sqlx (PostgreSQL) | 0.3-0.8 | 10 |
| diesel | 0.3-0.8 | cores |
| redis-rs | 0.2-0.5 | 1 |
| reqwest pool | 0.1-0.3 | Unlimited per host |

### GC Characteristics

| Metric | Value |
|---|---|
| GC Algorithm | None (ownership model) |
| Headroom Factor | 0.0 |
| CPU Overhead | 0% (no GC pauses) |
| Memory Management | Compile-time, deterministic |

### CPU Throughput Baseline

| Operation Type | Requests/sec/core |
|---|---|
| Simple REST (JSON CRUD) | 8000-15000 |
| Complex business logic | 3000-8000 |
| Database-heavy | 2000-5000 |
| File processing | 500-2000 |

### Rust Type Sizes

| Rust Type | Typical DB Column | Bytes |
|---|---|---|
| `String` (short) | VARCHAR(50) | 50 |
| `String` (medium) | VARCHAR(255) | 255 |
| `i32` | INTEGER | 4 |
| `i64` | BIGINT | 8 |
| `f64` | DOUBLE | 8 |
| `bool` | BOOLEAN | 1 |
| `chrono::DateTime<Utc>` | TIMESTAMPTZ | 12 |
| `uuid::Uuid` | UUID | 16 |
| `Vec<u8>` | BYTEA | variable |

---

## Database Type Sizes

Common database column type sizes for row size estimation (independent of language):

| SQL Type | Bytes (fixed) | Bytes (avg estimate) | Notes |
|---|---|---|---|
| BOOLEAN | 1 | 1 | |
| SMALLINT | 2 | 2 | |
| INTEGER | 4 | 4 | |
| BIGINT / BIGSERIAL | 8 | 8 | |
| REAL (float4) | 4 | 4 | |
| DOUBLE PRECISION | 8 | 8 | |
| DECIMAL/NUMERIC | 16 | 16 | Variable, 16 is safe estimate |
| VARCHAR(N) | variable | N/2 | Half of max is reasonable avg |
| TEXT | variable | 500 | Highly variable, 500 is conservative |
| UUID | 16 | 16 | |
| TIMESTAMP | 8 | 8 | |
| TIMESTAMPTZ | 8 | 8 | Stored same as TIMESTAMP in PG |
| DATE | 4 | 4 | |
| BYTEA | variable | 1000 | Highly variable |
| JSONB | variable | 500 | Highly variable |
| ARRAY | variable | 100 | Depends on element type and count |

**Row overhead:** Add ~23 bytes per row for PostgreSQL tuple header (HeapTupleHeaderData).

**Index overhead multiplier:** For each index on a table, add approximately:
- B-tree index: 3× the indexed column size per row
- GIN index (JSONB): 4-6× the indexed data size
- GiST index: 2-4× the indexed data size

**TOAST threshold:** PostgreSQL TOASTs (compresses/externalizes) values > 2KB. Factor this
into storage estimates for large TEXT/BYTEA/JSONB columns.
