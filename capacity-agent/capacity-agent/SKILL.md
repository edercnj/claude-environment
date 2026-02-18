---
name: capacity-agent
description: >
  Architect Sizing & Capacity Agent (ASCA). Analyzes source code and data models
  to calculate infrastructure requirements (CPU, RAM, Disk, Network) and generate
  a capacity planning report in Markdown. Use this skill whenever the user asks about
  infrastructure sizing, capacity planning, resource estimation, hardware requirements,
  cloud instance sizing, or wants to know how much CPU/RAM/Disk their application needs.
  Also trigger when users mention "how many pods", "what instance type", "server requirements",
  "scaling estimates", or "production sizing" for any codebase.
---

# Capacity Agent (ASCA)

## Overview

The Architect Sizing & Capacity Agent analyzes application source code, configuration files,
and data models to produce infrastructure capacity estimates. It works by scanning the codebase
to discover architectural components (entrypoints, outbound connections, data models, concurrency
settings), then applies language-specific formulas to estimate Memory, CPU, Disk, and Network
requirements. The output is a Markdown report with per-environment sizing tables, bottleneck
analysis, and scaling recommendations.

The agent is **language-agnostic** — it ships with built-in profiles for Java, Go, Python,
TypeScript/Node.js, and Rust, but the analysis approach generalizes to any stack. The key
insight is that capacity estimation follows predictable patterns: every application has
entrypoints that accept traffic, outbound connections that consume resources, data models
that determine storage, and a concurrency model that sets the memory/CPU envelope.

## Workflow

The analysis follows 6 sequential phases. Each phase feeds data into the next.

### Phase 1 — Discovery

Scan the codebase to identify architectural components. This is the foundation — everything
else depends on accurate discovery.

**What to find:**

1. **Language & Framework** — Detect from build files:
   - `pom.xml` / `build.gradle` → Java (check for Quarkus, Spring Boot, Micronaut)
   - `go.mod` → Go (check for Gin, Echo, Fiber)
   - `requirements.txt` / `pyproject.toml` → Python (check for Django, FastAPI, Flask)
   - `package.json` → TypeScript/Node.js (check for Express, NestJS, Fastify)
   - `Cargo.toml` → Rust (check for Actix, Axum, Rocket)

2. **Entrypoints** — These are where traffic arrives:
   - HTTP/REST handlers (routes, controllers, resources)
   - gRPC service definitions
   - Message consumers (Kafka, RabbitMQ, SQS listeners)
   - Scheduled jobs / cron tasks
   - TCP/UDP socket servers
   - GraphQL resolvers

3. **Outbound connections** — These consume connection pool resources:
   - Database connections (JDBC, connection strings, ORM configs)
   - HTTP clients (REST clients, Feign, WebClient)
   - Cache connections (Redis, Memcached)
   - Message producers (Kafka, RabbitMQ)
   - External API integrations

4. **Data models** — These determine storage requirements:
   - ORM entities / database models (JPA, Hibernate, SQLAlchemy, TypeORM, GORM)
   - Table definitions in migration files
   - Document schemas (MongoDB, DynamoDB)

5. **Concurrency configuration** — This sets the resource envelope:
   - Thread pool sizes (executor services, worker threads)
   - Connection pool sizes (HikariCP, pgBouncer, etc.)
   - Event loop / reactor configuration
   - Worker/process counts (Gunicorn workers, PM2 instances)

6. **Existing infrastructure hints** — Check for declared resource limits:
   - Kubernetes manifests (requests/limits in Deployment)
   - Docker Compose resource constraints
   - Cloud formation / Terraform instance types
   - `application.properties` / `application.yml` tuning parameters

After discovering all components, load the appropriate language profile from
`references/lang-profiles.md`. The profile provides memory weights, concurrency costs,
type sizes, and GC characteristics specific to the detected language/framework.

### Phase 2 — Memory Calculation

Memory is typically the most constrained resource. Calculate it bottom-up:

```
Total Memory = Base Overhead + Concurrency Memory + Pool Memory + GC Headroom + Safety Margin
```

**Base Overhead** — The runtime itself before any application code runs:
- Read from language profile (e.g., Java/Quarkus native ~40MB, Java/Spring JVM ~200MB, Go ~10MB, Node.js ~50MB)
- Add framework overhead from profile

**Concurrency Memory** — Memory consumed by concurrent request handling:
```
Concurrency Memory = max_concurrent_requests × per_request_memory
```
Where:
- `max_concurrent_requests` = thread pool size OR event loop concurrency setting
- `per_request_memory` = stack size + average heap allocation per request
- Read stack size and allocation estimates from language profile
- If the code has large in-memory operations (file processing, image manipulation,
  report generation), increase per_request_memory proportionally

**Pool Memory** — Memory consumed by connection pools:
```
Pool Memory = Σ (pool_size × per_connection_memory)
```
For each connection pool discovered:
- Database connections: typically 0.5-2MB per connection (varies by driver)
- Redis connections: ~1MB per connection
- HTTP client pools: ~0.5MB per connection
- Read specific values from language profile

**GC Headroom** — Only for GC-based languages (Java, Go, C#, Python):
```
GC Headroom = (Base + Concurrency + Pool) × gc_headroom_factor
```
- Java G1GC: factor = 0.5 (need ~50% headroom for GC to operate efficiently)
- Java ZGC/Shenandoah: factor = 0.3
- Go: factor = 0.25
- Python: factor = 0.15
- Rust/C/C++: factor = 0 (no GC)

**Safety Margin** — Always add 20% on top of everything:
```
Safety Margin = (Base + Concurrency + Pool + GC Headroom) × 0.20
```

**Deep Analysis Additions:**
When doing deep analysis, also account for:
- Caching layers (in-memory caches like Caffeine, node-cache, lru-cache)
  - Estimate cache size from configuration or defaults
- Large object allocations (file buffers, serialization buffers)
  - Scan for byte array allocations, Buffer usage, stream processing
- Class metadata / reflection overhead (significant in Java/Spring)

### Phase 3 — CPU Calculation

CPU requirements depend on throughput targets and per-request processing cost.

```
Required vCPUs = (target_rps / adjusted_throughput_per_core) × overhead_factor
```

**Adjusted Throughput Per Core** — How many requests one core can handle:
- Start with language baseline from profile (e.g., Java ~2000 simple req/s/core, Go ~5000, Node.js ~3000)
- Apply complexity factor based on what the code does:

| Operation in hot path | Complexity multiplier |
|---|---|
| Simple CRUD (DB read/write) | 1.0× |
| JSON serialization of large objects | 0.8× |
| Encryption/hashing per request | 0.7× |
| Image/file processing | 0.3× |
| Complex business logic (many branches) | 0.6× |
| External API calls (mostly I/O wait) | 1.2× (CPU idle during wait) |

If the hot path involves multiple operations, multiply the factors together.

**Overhead Factor** — Account for non-request CPU usage:
```
overhead_factor = 1.0 + gc_cpu_overhead + background_task_overhead
```
- GC CPU overhead: Java G1 ~0.10, Go ~0.05, Python ~0.03
- Background tasks: scan for @Scheduled, cron jobs, health checks → add 0.05-0.15
- Monitoring/metrics collection → add 0.05

**Deep Analysis Additions:**
- Cyclomatic complexity scoring: scan methods in hot paths, high complexity = more CPU
- Regex usage in hot paths: regex is CPU-intensive, flag and adjust
- Serialization/deserialization volume: large DTOs = more CPU for JSON/protobuf

### Phase 4 — Disk Calculation

Disk requirements come from persistent data, logs, and temporary storage.

```
Total Disk = Database Storage + Log Storage + Temp Storage + Index Overhead
```

**Database Storage:**
```
DB Storage = Σ (avg_row_size × write_rate × retention_period)
```
For each entity/table discovered:
- Estimate `avg_row_size` from column types (use type sizes from language profile)
- Estimate `write_rate` from entrypoint analysis (how many writes per request?)
- Apply `retention_period` from configuration or assume 1 year default
- Add **index overhead**: typically 1.5× to 3× raw data size depending on index count

**Log Storage:**
```
Log Storage = avg_log_line_size × log_lines_per_request × rps × retention_days × 86400
```
- Structured JSON logs: ~500 bytes per line
- Plain text logs: ~200 bytes per line
- Estimate log lines per request from logging configuration (DEBUG=10+, INFO=3-5, WARN=1-2)

**Temp Storage:**
- File upload processing: estimate from max upload size × concurrent uploads
- Report generation: estimate from output size × concurrent generations
- Build artifacts (if CI): typically 2-5GB

**Growth Projection:**
Always project disk growth over time:
- 3 months, 6 months, 1 year, 2 years
- Apply monthly growth rate (default 10% if not specified)
- Include compaction/cleanup effects if applicable (e.g., log rotation)

### Phase 5 — Network Estimation

Network bandwidth is usually not the bottleneck, but estimate it for completeness.

```
Ingress = avg_request_size × target_rps
Egress = avg_response_size × target_rps
```

**Estimate sizes from:**
- Request DTOs: sum field sizes from discovered request models
- Response DTOs: sum field sizes from discovered response models
- Add protocol overhead: HTTP headers ~500 bytes, TLS ~50 bytes, TCP ~40 bytes
- For binary protocols (gRPC, ISO 8583): use actual message sizes from schemas

**Connection count:**
```
Concurrent Connections = target_rps × avg_response_time_seconds
```
This matters for load balancer sizing and connection limit configuration.

### Phase 6 — Report Generation

Generate the final Markdown report using the template in `references/report-template.md`.

The report MUST include:

1. **Executive Summary** — One paragraph with the key finding (what's the primary constraint?)
2. **Application Profile** — Language, framework, detected components summary
3. **Environment Sizing Table** — Three environments (Dev, Staging, Production) with:
   - vCPUs, Memory (MB), Disk (GB), Network (Mbps)
   - Suggested instance type (AWS, GCP, Azure equivalents)
   - Number of replicas
4. **Detailed Calculations** — Show the math for each dimension with discovered values
5. **Bottleneck Analysis** — Identify which resource will be exhausted first
6. **Scaling Recommendations** — When to scale horizontally vs vertically
7. **Assumptions & Caveats** — What was assumed, what couldn't be determined from code alone

**Environment multipliers:**
| Environment | CPU | Memory | Disk | Replicas |
|---|---|---|---|---|
| Dev | 0.25× | 0.5× | 0.1× | 1 |
| Staging | 0.5× | 0.75× | 0.25× | 2 |
| Production | 1.0× | 1.0× | 1.0× | 3+ (based on HA needs) |

## Bottleneck Detection

After calculating all dimensions, identify the primary bottleneck:

| Pattern | Indicator | Typical Cause |
|---|---|---|
| **Memory-bound** | Memory scales faster than CPU | Large per-request allocations, big caches, many connections |
| **CPU-bound** | CPU saturates before memory | Complex business logic, encryption, serialization |
| **IO-bound** | Low CPU/Memory but high latency | Database queries, external API calls, disk I/O |
| **Connection-bound** | Pool exhaustion before resource limits | Too many outbound integrations, small pool sizes |
| **Disk-bound** | Disk fills before other limits | High write throughput, large log volume, no rotation |

The report should clearly state which bottleneck was detected and recommend
mitigation strategies specific to that pattern.

## Scaling Recommendations

Based on the bottleneck pattern, recommend scaling strategy:

| Bottleneck | Scale Strategy | Specific Actions |
|---|---|---|
| Memory-bound | Vertical first, then horizontal | Increase instance memory; optimize allocations; reduce cache sizes |
| CPU-bound | Horizontal | Add replicas; optimize hot paths; consider async processing |
| IO-bound | Optimize I/O | Add caching layer; optimize queries; use connection pooling |
| Connection-bound | Pool tuning | Increase pool sizes; add connection pooling proxy (PgBouncer) |
| Disk-bound | Storage optimization | Add log rotation; archive old data; use compression |

## Important Considerations

**What the agent CAN determine from code:**
- Architectural components and their relationships
- Configured pool sizes and thread counts
- Data model structure and approximate row sizes
- Concurrency model and request handling patterns
- Framework-specific overhead patterns

**What the agent CANNOT determine from code (must be provided or assumed):**
- Actual traffic volume (target RPS) — ask the user or assume a default
- Data retention policies — check configuration or assume 1 year
- Peak-to-average traffic ratio — assume 3× if not specified
- Actual query complexity (N+1 problems, full table scans)
- Third-party API response times
- Real-world payload sizes (only estimates from DTOs)

When a value cannot be determined, the report must clearly state the assumption
made and its impact on the estimate. Use conservative (higher) estimates when uncertain.

## Resources

### references/lang-profiles.md

Contains built-in language profiles with memory weights, concurrency costs, type sizes,
framework overheads, and GC characteristics for Java, Go, Python, TypeScript, and Rust.
Read this file during Phase 1 after detecting the language.

### references/report-template.md

Contains the Markdown template for the final capacity report. Read this during Phase 6
to generate consistent, well-structured output.
