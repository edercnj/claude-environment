# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 24 — Application Resilience

## Principles
- **Fail Secure:** In case of failure, DENY transaction (RC 96) — NEVER approve
- **Failure Isolation:** Failure in one component does NOT propagate to others
- **Graceful Degradation:** Under pressure, reduce functionality progressively instead of collapsing
- **Observability:** Every resilience event MUST generate a metric and log
- **Application-Level:** Resilience is the responsibility of the application, NOT the orchestrator (K8S)
- **Zero Vendor Lock-in:** Use MicroProfile Fault Tolerance (SmallRye), NEVER proprietary APIs

## Technology Stack

| Pattern | Technology | Justification |
|---------|-----------|---------------|
| Circuit Breaker | MicroProfile Fault Tolerance (`@CircuitBreaker`) | Native Quarkus, CDI-aware, native build |
| Retry | MicroProfile Fault Tolerance (`@Retry`) | Configuration via `application.properties` |
| Timeout | MicroProfile Fault Tolerance (`@Timeout`) | Integrated with Vert.x event loop |
| Bulkhead | MicroProfile Fault Tolerance (`@Bulkhead`) | Isolation via semaphore or thread pool |
| Fallback | MicroProfile Fault Tolerance (`@Fallback`) | Declarative degradation |
| Rate Limiting | Bucket4j (in-memory) | Token Bucket, high performance, no external dependency |
| Backpressure | Vert.x native (`pause`/`resume`) | Already available in TCP stack, zero overhead |
| Health/Degradation | SmallRye Health (custom checks) | Exposes state via `/q/health` |

### Why MicroProfile Fault Tolerance (and NOT Resilience4j)

| Criterion | MP Fault Tolerance | Resilience4j |
|----------|-------------------|-------------|
| Quarkus Integration | Native (SmallRye) | Requires adapter |
| Configuration | `application.properties` | Programmatic or YAML |
| CDI-aware | Yes, automatic | No |
| Native build | Supported | Requires extra configuration |
| Standard | Jakarta EE / MicroProfile | Proprietary |
| Automatic Metrics | Yes (OpenTelemetry) | Requires bridge |

## 1. Rate Limiting (Flow Control)

### Scopes

| Scope | Algorithm | Default Limit | Configurable |
|-------|-----------|---------------|-------------|
| REST API per IP | Token Bucket | 100 req/s | `simulator.resilience.rate-limit.rest-per-ip` |
| REST API per endpoint (POST) | Fixed Window | 10 req/s | `simulator.resilience.rate-limit.rest-post` |
| TCP Socket per connection | Token Bucket | 50 msg/s | `simulator.resilience.rate-limit.tcp-per-connection` |
| TCP Socket global | Sliding Window | 5000 msg/s | `simulator.resilience.rate-limit.tcp-global` |

### Implementation — Bucket4j

```java
@ApplicationScoped
public class RateLimiter {

    private static final Logger LOG = Logger.getLogger(RateLimiter.class);
    private static final int MAX_BUCKETS = 10_000;
    private static final Duration IDLE_EVICTION_THRESHOLD = Duration.ofMinutes(5);

    private final ConcurrentHashMap<String, TimestampedBucket> buckets = new ConcurrentHashMap<>();
    private final Bandwidth defaultBandwidth;

    @Inject
    public RateLimiter(SimulatorConfig config) {
        this.defaultBandwidth = Bandwidth.classic(
            config.resilience().rateLimit().tcpPerConnection(),
            Refill.intervally(
                config.resilience().rateLimit().tcpPerConnection(),
                Duration.ofSeconds(1)
            )
        );
    }

    public ConsumptionResult tryConsume(String key) {
        if (buckets.size() >= MAX_BUCKETS && !buckets.containsKey(key)) {
            LOG.warnf("Rate limiter bucket limit reached (%d), rejecting new key: %s", MAX_BUCKETS, key);
            return new ConsumptionResult(false, Duration.ofSeconds(1).toNanos());
        }
        var timestamped = buckets.computeIfAbsent(key, k ->
            new TimestampedBucket(Bucket.builder().addLimit(defaultBandwidth).build()));
        timestamped.touch();
        var probe = timestamped.bucket().tryConsumeAndReturnRemaining(1);
        return new ConsumptionResult(probe.isConsumed(), probe.getNanosToWaitForRefill());
    }

    public void evict(String key) {
        buckets.remove(key);
    }

    @Scheduled(every = "60s")
    void evictIdleBuckets() {
        var cutoff = Instant.now().minus(IDLE_EVICTION_THRESHOLD);
        int before = buckets.size();
        buckets.entrySet().removeIf(e -> e.getValue().lastAccess().isBefore(cutoff));
        int evicted = before - buckets.size();
        if (evicted > 0) {
            LOG.infof("Evicted %d idle rate limit buckets (remaining=%d)", evicted, buckets.size());
        }
    }

    public record ConsumptionResult(boolean consumed, long nanosToWaitForRefill) {
        public long retryAfterSeconds() {
            return Math.max(1, TimeUnit.NANOSECONDS.toSeconds(nanosToWaitForRefill));
        }
    }

    private static final class TimestampedBucket {
        private final Bucket bucket;
        private volatile Instant lastAccess;

        TimestampedBucket(Bucket bucket) {
            this.bucket = bucket;
            this.lastAccess = Instant.now();
        }

        Bucket bucket() { return bucket; }
        Instant lastAccess() { return lastAccess; }
        void touch() { this.lastAccess = Instant.now(); }
    }
}
```

### REST API — JAX-RS Filter

```java
@Provider
@Priority(Priorities.AUTHENTICATION - 100)
public class RateLimitFilter implements ContainerRequestFilter {

    private static final Logger LOG = Logger.getLogger(RateLimitFilter.class);

    private final RateLimiter rateLimiter;

    @Inject
    public RateLimitFilter(RateLimiter rateLimiter) {
        this.rateLimiter = rateLimiter;
    }

    @Override
    public void filter(ContainerRequestContext requestContext) {
        var clientIp = extractClientIp(requestContext);
        var result = rateLimiter.tryConsume("rest:" + clientIp);
        if (!result.consumed()) {
            LOG.warnf("Rate limit exceeded for IP: %s", clientIp);
            requestContext.abortWith(
                Response.status(429)
                    .header("Retry-After", String.valueOf(result.retryAfterSeconds()))
                    .entity(ProblemDetail.tooManyRequests(
                        "Rate limit exceeded", requestContext.getUriInfo().getPath()))
                    .build()
            );
        }
    }
}
```

### TCP Socket — In Handler

```java
// Inside TCP message handler
var result = rateLimiter.tryConsume("tcp:" + context.connectionId());
if (!result.consumed()) {
    LOG.warnf("Rate limit exceeded for connection: %s (retry in %ds)",
        context.connectionId(), result.retryAfterSeconds());
    metrics.recordRateLimitRejected("tcp", context.connectionId());
    return buildErrorResponse(RESPONSE_CODE_SYSTEM_ERROR); // RC 96
}
```

### Response to Rate Limit

| Channel | Action | Code |
|---------|--------|------|
| REST API | HTTP 429 + `Retry-After` header | 429 Too Many Requests |
| TCP Socket | ISO response with RC 96 | Response Code 96 |
| TCP Global | Reject new connection | Connection refused |

## 2. Circuit Breaker (Breaker)

### Circuits

| Circuit | Monitors | Failure Ratio | Window | Delay |
|---------|----------|---------------|--------|-------|
| `db-write` | INSERT/UPDATE on PostgreSQL | 50% of 10 calls | Rolling 10s | 30s |
| `db-read` | SELECT on PostgreSQL | 50% of 10 calls | Rolling 10s | 30s |
| `decision-engine` | Exceptions in CentsDecisionEngine | 30% of 10 calls | Rolling 5s | 15s |

### Implementation

```java
@ApplicationScoped
public class PostgresPersistenceAdapter implements PersistencePort {

    private final TransactionRepository repository;

    @Inject
    public PostgresPersistenceAdapter(TransactionRepository repository) {
        this.repository = repository;
    }

    @Override
    @CircuitBreaker(
        requestVolumeThreshold = 10,
        failureRatio = 0.5,
        delay = 30000,
        successThreshold = 3
    )
    @Fallback(fallbackMethod = "saveFallback")
    public void save(Transaction transaction) {
        repository.persist(TransactionEntityMapper.toEntity(transaction));
    }

    private void saveFallback(Transaction transaction) {
        LOG.errorf("Circuit OPEN — cannot persist transaction STAN=%s, failing secure", transaction.stan());
        throw new PersistenceUnavailableException(transaction.stan());
    }

    @Override
    @CircuitBreaker(
        requestVolumeThreshold = 10,
        failureRatio = 0.5,
        delay = 30000,
        successThreshold = 3
    )
    @Fallback(fallbackMethod = "findFallback")
    public Optional<Transaction> findByStanAndDate(String stan, String date) {
        return repository.findByStanAndDate(stan, date).map(TransactionEntityMapper::toDomain);
    }

    private Optional<Transaction> findFallback(String stan, String date) {
        LOG.errorf("Circuit OPEN — cannot query transactions, returning empty");
        return Optional.empty();
    }
}
```

### Circuit Breaker States

```
CLOSED (normal) ──[failure ratio ≥ threshold]──► OPEN (rejects everything)
                                                     │
                                                 [delay expires]
                                                     │
                                                     ▼
                                              HALF_OPEN (tests)
                                                     │
                                    ┌────────────────┼────────────────┐
                              [success ≥ N]                    [failure]
                                    │                              │
                                    ▼                              ▼
                                 CLOSED                          OPEN
```

### Behavior by State

| State | TCP (ISO 8583) | REST API |
|-------|---------------|----------|
| CLOSED | Normal processing | Normal processing |
| OPEN | RC 96 (System Error) | HTTP 503 + `Retry-After` |
| HALF_OPEN | Process 1 test message | Process 1 test request |

### Golden Rule — Fail Secure

> When the circuit breaker for the database is OPEN, **ALL** ISO 8583 transactions
> MUST be denied with RC 96. NEVER approve a transaction without persisting.

## 3. Bulkhead (Load Isolation)

### Partitions

| Bulkhead | Type | Capacity | Waiting Queue |
|----------|------|-----------|---------------|
| `tcp-processing` | Semaphore | 80 | 20 |
| `rest-processing` | Semaphore | 20 | 10 |
| `db-operations` | Semaphore | 15 | 5 |
| `timeout-simulation` | Thread Pool | 10 threads | 5 |

### Implementation

```java
@ApplicationScoped
public class AuthorizeTransactionUseCase {

    @Bulkhead(value = 80, waitingTaskQueue = 20)
    @Fallback(fallbackMethod = "authorizeFallback")
    public TransactionResult authorize(IsoMessage request) {
        // normal processing
    }

    private TransactionResult authorizeFallback(IsoMessage request) {
        LOG.warnf("Bulkhead full — rejecting transaction MTI=%s", request.getMti());
        return TransactionResult.systemError("Bulkhead capacity exceeded");
    }
}
```

### TCP vs REST Isolation

```
Worker Threads (Vert.x Event Loop)
├── TCP Bulkhead (80 slots) ──► ISO 8583 message processing
│   └── DB Bulkhead (15 slots) ──► PostgreSQL operations
├── REST Bulkhead (20 slots) ──► REST API request processing
│   └── DB Bulkhead (shared) ──► PostgreSQL operations
└── Timeout Pool (10 threads) ──► RULE-002 delay simulation
```

> Timeout Simulation (RULE-002) MUST use a separate thread pool to NEVER
> block the Vert.x event loop or consume slots from the main bulkhead.

## 4. Timeout (Time Control)

### Limits

| Operation | Timeout | Action if Exceeded |
|-----------|---------|-----------------|
| DB query (SELECT) | 5s | Abort + RC 96 |
| DB write (INSERT/UPDATE) | 5s | Abort + RC 96 |
| DB connection acquire | 3s | Abort + RC 96 |
| ISO message processing (total) | 10s | Abort + RC 96 |
| REST request processing | 30s | HTTP 503 |
| Timeout simulation (RULE-002) | 35s (intentional) | Respond normally |

### Implementation

```java
@ApplicationScoped
public class AuthorizeTransactionUseCase {

    @Timeout(value = 10000) // 10s in millis (MP FT default unit)
    @Fallback(fallbackMethod = "timeoutFallback")
    public TransactionResult authorize(IsoMessage request) {
        // normal processing
    }

    private TransactionResult timeoutFallback(IsoMessage request) {
        LOG.errorf("Processing timeout — MTI=%s STAN=%s", request.getMti(), request.getStan());
        return TransactionResult.systemError("Processing timeout");
    }
}
```

### Exception: RULE-002 (Timeout Simulation)

The timeout simulation (RULE-002) is **intentional** and MUST NOT be intercepted
by `@Timeout`. Use a separate thread pool (dedicated bulkhead):

```java
@Bulkhead(value = 10, waitingTaskQueue = 5)
// NO @Timeout here — the 35s delay is intentional
public TransactionResult authorizeWithSimulatedTimeout(IsoMessage request, int delaySeconds) {
    Thread.sleep(delaySeconds * 1000L); // Intentional — dedicated pool
    return authorize(request);
}
```

## 5. Retry (Retries)

### Policy

| Operation | Retry? | Max Attempts | Delay | Jitter |
|-----------|--------|-------------|-------|--------|
| DB read (SELECT) | Yes | 2 | 100ms → 200ms (exponential) | 50ms |
| DB connection acquire | Yes | 3 | 500ms (fixed) | 100ms |
| DB write (INSERT) | **NO** | — | — | — |
| ISO message processing | **NO** | — | — | — |
| Health check query | Yes | 3 | 1s (fixed) | 200ms |

### Retry Rules

- **NEVER** retry on non-idempotent operations (transaction INSERT)
- **NEVER** retry on business errors (validation, RC != 00)
- **ONLY** retry on transient failures (connection reset, network timeout)
- **ALWAYS** with jitter to avoid thundering herd
- **ALWAYS** with max attempts to avoid infinite retry

### Implementation

```java
@ApplicationScoped
public class PostgresPersistenceAdapter implements PersistencePort {

    @Override
    @Retry(
        maxRetries = 2,
        delay = 100,
        maxDuration = 2000,
        jitter = 50,
        retryOn = {SQLException.class, PersistenceException.class},
        abortOn = {ConstraintViolationException.class}
    )
    public Optional<Transaction> findByStanAndDate(String stan, String date) {
        return repository.findByStanAndDate(stan, date).map(TransactionEntityMapper::toDomain);
    }

    // NO @Retry — INSERT is not idempotent
    @Override
    public void save(Transaction transaction) {
        repository.persist(TransactionEntityMapper.toEntity(transaction));
    }
}
```

### Retryable vs Non-Retryable Exceptions

| Retryable (transient) | Non-Retryable (permanent) |
|--------------------------|---------------------------|
| `java.sql.SQLException` (connection reset) | `ConstraintViolationException` (unique) |
| `PersistenceException` (lock timeout) | `ValidationException` (invalid data) |
| `java.net.SocketTimeoutException` | `MessageParsingException` (invalid ISO) |
| `java.io.IOException` (network) | Any business exception |

## 6. Fallback (Graceful Degradation)

### Strategies by Component

| Component | Trigger | Fallback | Result |
|-----------|---------|----------|-----------|
| DB write | Circuit open / timeout | Log + throw | RC 96 (fail secure) |
| DB read | Circuit open / timeout | `Optional.empty()` | RC 96 if data was mandatory |
| Decision Engine | Unexpected exception | RC 96 | **NEVER approve** |
| Rate Limit (TCP) | Bucket empty | ISO response with RC 96 | Connection maintained |
| Rate Limit (REST) | Bucket empty | HTTP 429 + Retry-After | — |
| Bulkhead full | Queue full | Error response | RC 96 or HTTP 503 |

### Golden Rule — Fail Secure

```java
// ✅ CORRECT — fallback denies transaction
@Fallback(fallbackMethod = "decideFallback")
public String decide(BigDecimal amount) {
    return centsDecisionEngine.decide(amount);
}

private String decideFallback(BigDecimal amount) {
    LOG.error("Decision engine fallback — denying transaction");
    return RESPONSE_CODE_SYSTEM_ERROR; // RC 96
}

// ❌ WRONG — fallback approves transaction
private String decideFallback(BigDecimal amount) {
    return RESPONSE_CODE_APPROVED; // DANGER: failure = approval
}
```

## 7. Backpressure (Counterpressure)

### TCP Socket — Vert.x Native

| Mechanism | Threshold | Action |
|-----------|-----------|------|
| Pending messages per connection | > 10 | `socket.pause()` |
| Resume threshold | ≤ 5 | `socket.resume()` |
| Pending messages global | > 1000 | Reject new connections |
| Response queue per connection | > 50 | Drop oldest idle connection |

### Implementation

```java
// Counters PER-CONNECTION (in ConnectionContext) and GLOBAL (in handler)
private final ConcurrentHashMap<String, AtomicInteger> pendingPerConnection = new ConcurrentHashMap<>();
private final AtomicInteger pendingGlobal = new AtomicInteger(0);

private void handleMessageBody(Buffer bodyBuffer, RecordParser parser, NetSocket socket, ConnectionContext context) {
    var connectionPending = pendingPerConnection
        .computeIfAbsent(context.connectionId(), k -> new AtomicInteger(0));
    int perConn = connectionPending.incrementAndGet();
    int global = pendingGlobal.incrementAndGet();

    // Per-connection backpressure: pause only THIS connection
    if (perConn > 10) {
        socket.pause();
        LOG.warnf("Backpressure activated for connection %s (pending=%d)", context.connectionId(), perConn);
        metrics.recordBackpressureActivated(context.connectionId());
    }

    // Global backpressure: reject new connections is done in accept handler (see ConnectionManager)
    if (global > 1000) {
        LOG.warnf("Global backpressure threshold exceeded (pending=%d)", global);
    }

    handler.process(bodyBuffer)
        .subscribe().with(
            response -> {
                socket.write(Buffer.buffer(frameMessage(response)));
                pendingGlobal.decrementAndGet();
                if (connectionPending.decrementAndGet() <= 5) {
                    socket.resume();
                    LOG.infof("Backpressure released for connection %s", context.connectionId());
                }
            },
            error -> {
                pendingGlobal.decrementAndGet();
                connectionPending.decrementAndGet();
                handleProcessingError(socket, context, error);
            }
        );
}

// Cleanup when closing connection
private void onConnectionClosed(String connectionId) {
    var removed = pendingPerConnection.remove(connectionId);
    if (removed != null) {
        pendingGlobal.addAndGet(-removed.get());
    }
}
```

## 8. Graceful Degradation (Progressive Degradation)

### Degradation Levels

| Level | Condition | Actions |
|-------|---------|-------|
| **NORMAL** | CPU < 70%, p99 < 200ms, circuits closed | Everything enabled |
| **WARNING** | CPU 70-85% OR p99 200-500ms | Reduce rate limit 50%, disable DEBUG logs |
| **CRITICAL** | CPU > 85% OR p99 > 500ms OR circuit open | Reject new TCP connections, only process existing |
| **EMERGENCY** | DB down OR multiple circuits open | Only echo test (1804→1814), reject everything with RC 96 |

### Implementation — Health-Based

```java
@ApplicationScoped
public class DegradationManager {

    private final ResilienceConfig.DegradationConfig config;
    private volatile DegradationLevel currentLevel = DegradationLevel.NORMAL;

    @Inject
    public DegradationManager(ResilienceConfig resilienceConfig) {
        this.config = resilienceConfig.degradation();
    }

    public DegradationLevel getCurrentLevel() {
        return currentLevel;
    }

    @Scheduled(every = "{simulator.resilience.degradation.evaluation-interval}")
    void evaluateDegradation() {
        var metrics = collectMetrics();
        var newLevel = calculateLevel(metrics);

        if (newLevel != currentLevel) {
            LOG.warnf("Degradation level changed: %s → %s", currentLevel, newLevel);
            currentLevel = newLevel;
        }
    }

    private DegradationLevel calculateLevel(SystemMetrics metrics) {
        if (metrics.dbCircuitOpen() || metrics.multipleCircuitsOpen()) {
            return DegradationLevel.EMERGENCY;
        }
        if (metrics.cpuUsage() > config.cpuCriticalThreshold()
                || metrics.p99LatencyMs() > config.latencyCriticalMs()
                || metrics.anyCircuitOpen()) {
            return DegradationLevel.CRITICAL;
        }
        if (metrics.cpuUsage() > config.cpuWarningThreshold()
                || metrics.p99LatencyMs() > config.latencyWarningMs()) {
            return DegradationLevel.WARNING;
        }
        return DegradationLevel.NORMAL;
    }
}
```

### Verification in Message Handler

```java
public byte[] processMessage(Buffer bodyBuffer, ConnectionContext context) {
    var level = degradationManager.getCurrentLevel();

    if (level == DegradationLevel.EMERGENCY) {
        var mti = extractMti(bodyBuffer);
        if (!"1804".equals(mti)) {
            LOG.warnf("EMERGENCY mode — rejecting non-echo message MTI=%s", mti);
            return buildErrorResponse(RESPONSE_CODE_SYSTEM_ERROR);
        }
    }

    if (level == DegradationLevel.CRITICAL) {
        if (!connectionManager.isExistingConnection(context.connectionId())) {
            LOG.warnf("CRITICAL mode — rejecting new connection %s", context.connectionId());
            throw new ConnectionRejectedException("System under critical load");
        }
    }

    return handler.process(bodyBuffer);
}
```

### Health Check — Level Exposure

```java
@Readiness
@ApplicationScoped
public class DegradationHealthCheck implements HealthCheck {

    private final DegradationManager degradationManager;

    @Inject
    public DegradationHealthCheck(DegradationManager degradationManager) {
        this.degradationManager = degradationManager;
    }

    @Override
    public HealthCheckResponse call() {
        var level = degradationManager.getCurrentLevel();
        var builder = HealthCheckResponse.named("degradation-level")
            .withData("level", level.name());

        return switch (level) {
            case NORMAL, WARNING -> builder.up().build();
            case CRITICAL -> builder.up().withData("warning", "system under high load").build();
            case EMERGENCY -> builder.down().withData("reason", "emergency degradation active").build();
        };
    }
}
```

## Configuration (`application.properties`)

```properties
# === Rate Limiting (Bucket4j) ===
simulator.resilience.rate-limit.rest-per-ip=100
simulator.resilience.rate-limit.rest-post=10
simulator.resilience.rate-limit.tcp-per-connection=50
simulator.resilience.rate-limit.tcp-global=5000

# === Circuit Breaker (MicroProfile FT override via config) ===
# DB Write circuit
PostgresPersistenceAdapter/save/CircuitBreaker/requestVolumeThreshold=10
PostgresPersistenceAdapter/save/CircuitBreaker/failureRatio=0.5
PostgresPersistenceAdapter/save/CircuitBreaker/delay=30000
PostgresPersistenceAdapter/save/CircuitBreaker/successThreshold=3

# DB Read circuit
PostgresPersistenceAdapter/findByStanAndDate/CircuitBreaker/requestVolumeThreshold=10
PostgresPersistenceAdapter/findByStanAndDate/CircuitBreaker/failureRatio=0.5
PostgresPersistenceAdapter/findByStanAndDate/CircuitBreaker/delay=30000

# === Bulkhead ===
AuthorizeTransactionUseCase/authorize/Bulkhead/value=80
AuthorizeTransactionUseCase/authorize/Bulkhead/waitingTaskQueue=20

# === Timeout (values in milliseconds — MP FT default unit) ===
AuthorizeTransactionUseCase/authorize/Timeout/value=10000

# === Retry ===
PostgresPersistenceAdapter/findByStanAndDate/Retry/maxRetries=2
PostgresPersistenceAdapter/findByStanAndDate/Retry/delay=100
PostgresPersistenceAdapter/findByStanAndDate/Retry/jitter=50

# === Degradation ===
simulator.resilience.degradation.evaluation-interval=5s
simulator.resilience.degradation.cpu-warning-threshold=70
simulator.resilience.degradation.cpu-critical-threshold=85
simulator.resilience.degradation.latency-warning-ms=200
simulator.resilience.degradation.latency-critical-ms=500
```

## ConfigMapping

```java
@ConfigMapping(prefix = "simulator.resilience")
public interface ResilienceConfig {

    RateLimitConfig rateLimit();
    DegradationConfig degradation();

    interface RateLimitConfig {
        @WithDefault("100")
        int restPerIp();

        @WithDefault("10")
        int restPost();

        @WithDefault("50")
        int tcpPerConnection();

        @WithDefault("5000")
        int tcpGlobal();
    }

    interface DegradationConfig {
        @WithDefault("5s")
        String evaluationInterval();

        @WithDefault("70")
        int cpuWarningThreshold();

        @WithDefault("85")
        int cpuCriticalThreshold();

        @WithDefault("200")
        int latencyWarningMs();

        @WithDefault("500")
        int latencyCriticalMs();
    }
}
```

## Resilience Metrics (OpenTelemetry)

### Automatic Metrics (SmallRye FT + OpenTelemetry)

SmallRye Fault Tolerance exposes metrics automatically when `quarkus-smallrye-fault-tolerance`
is on the classpath with OpenTelemetry enabled:

| Metric | Type | Tags |
|--------|------|------|
| `ft.circuitbreaker.state.total` | Gauge | method, state (closed/open/halfOpen) |
| `ft.circuitbreaker.calls.total` | Counter | method, result (success/failure/cbOpen) |
| `ft.bulkhead.executionsRunning` | Gauge | method |
| `ft.bulkhead.executionsWaiting` | Gauge | method |
| `ft.bulkhead.callsAccepted.total` | Counter | method |
| `ft.bulkhead.callsRejected.total` | Counter | method |
| `ft.retry.calls.total` | Counter | method, retried (true/false), result |
| `ft.retry.retries.total` | Counter | method |
| `ft.timeout.calls.total` | Counter | method, timedOut (true/false) |
| `ft.fallback.calls.total` | Counter | method |

### Custom Metrics (Application)

| Metric | Type | Tags |
|--------|------|------|
| `simulator.rate_limit.accepted` | Counter | scope (tcp/rest), client_key |
| `simulator.rate_limit.rejected` | Counter | scope (tcp/rest), client_key |
| `simulator.degradation.level` | Gauge | — |
| `simulator.degradation.level_changes` | Counter | from_level, to_level |
| `simulator.backpressure.activations` | Counter | connection_id |

### Custom Metrics Implementation

```java
@ApplicationScoped
public class ResilienceMetrics {

    private final LongCounter rateLimitAccepted;
    private final LongCounter rateLimitRejected;
    private final LongCounter degradationChanges;

    @Inject
    public ResilienceMetrics(Meter meter) {
        this.rateLimitAccepted = meter.counterBuilder("simulator.rate_limit.accepted")
            .setDescription("Requests accepted by rate limiter")
            .build();
        this.rateLimitRejected = meter.counterBuilder("simulator.rate_limit.rejected")
            .setDescription("Requests rejected by rate limiter")
            .build();
        this.degradationChanges = meter.counterBuilder("simulator.degradation.level_changes")
            .setDescription("Degradation level transitions")
            .build();
    }

    public void recordRateLimitAccepted(String scope, String clientKey) {
        rateLimitAccepted.add(1, Attributes.builder()
            .put("scope", scope).put("client_key", clientKey).build());
    }

    public void recordRateLimitRejected(String scope, String clientKey) {
        rateLimitRejected.add(1, Attributes.builder()
            .put("scope", scope).put("client_key", clientKey).build());
    }

    public void recordDegradationChange(DegradationLevel from, DegradationLevel to) {
        degradationChanges.add(1, Attributes.builder()
            .put("from_level", from.name()).put("to_level", to.name()).build());
    }
}
```

## Logging Resilience Events

All resilience events MUST be logged with context:

| Event | Level | Mandatory Fields |
|--------|-------|---------------------|
| Rate limit rejected | WARN | scope, client_key, current_rate |
| Circuit opened | ERROR | circuit_name, failure_count, failure_ratio |
| Circuit half-opened | INFO | circuit_name |
| Circuit closed | INFO | circuit_name, success_count |
| Bulkhead rejected | WARN | bulkhead_name, active_count, queue_size |
| Timeout triggered | ERROR | operation, duration_ms, threshold_ms |
| Retry attempted | WARN | operation, attempt, max_attempts, error |
| Fallback invoked | WARN | operation, reason |
| Degradation level changed | WARN | from_level, to_level, trigger_metric |
| Backpressure activated | WARN | connection_id, pending_count |
| Backpressure released | INFO | connection_id, pending_count |

## Maven Dependencies

```xml
<!-- MicroProfile Fault Tolerance (already includes SmallRye) -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-smallrye-fault-tolerance</artifactId>
</dependency>

<!-- Bucket4j (Rate Limiting) -->
<dependency>
    <groupId>com.bucket4j</groupId>
    <artifactId>bucket4j-core</artifactId>
    <version>${bucket4j.version}</version>
</dependency>
```

> No additional dependencies are needed for backpressure (Vert.x native)
> or health checks (SmallRye Health already included).

## Resilience Testing

### What to Test

| Scenario | Type | Validation |
|---------|------|-----------|
| Rate limit rejects over-limit | Unit | Request rejected, metric incremented |
| Circuit opens after failures | Integration | Fallback invoked, circuit state = OPEN |
| Circuit recovers after delay | Integration | State back to CLOSED after successes |
| Bulkhead rejects when full | Unit | Fallback invoked, metric incremented |
| Timeout triggers fallback | Integration | Fallback invoked within time |
| Retry succeeds on transient failure | Unit | Operation retried, success on 2nd attempt |
| Retry aborts on permanent failure | Unit | Operation NOT retried, exception propagated |
| Degradation level escalates | Unit | Correct level for each metric combination |
| Fail secure on all failures | Integration | RC 96 on ALL fallbacks, NEVER RC 00 |
| Backpressure pause/resume | Integration | Socket paused/resumed at thresholds |

### Naming Convention

```
[component]_[resiliencePattern]_[scenario]_[expectedBehavior]
```

Examples:
- `rateLimiter_tcpBucket_exceedsLimit_rejectsMessage`
- `circuitBreaker_dbWrite_multipleFailures_opensCircuit`
- `bulkhead_authorize_queueFull_invokesFallback`
- `degradation_emergency_dbDown_rejectsNonEcho`

## Anti-Patterns (PROHIBITED)

### General
- ❌ Approve transaction when fallback is invoked — **ALWAYS RC 96**
- ❌ Retry on non-idempotent operations (transaction INSERT)
- ❌ Retry without jitter — causes thundering herd
- ❌ Infinite retry — always define `maxRetries`
- ❌ Timeout longer than client timeout — response arrives after client gives up
- ❌ Circuit breaker on operations that already have natural fallback (ex: cache miss)
- ❌ Resilience4j or other proprietary lib — use MicroProfile Fault Tolerance

### Rate Limiting
- ❌ Global rate limit without per-client — one abusive client blocks all
- ❌ Rate limit without metric — impossible to detect abuse
- ❌ Rate limit without `Retry-After` header (REST) — client doesn't know when to retry

### Circuit Breaker
- ❌ Circuit breaker with too low threshold (1-2 failures) — opens due to normal fluctuation
- ❌ Circuit breaker with too long delay (> 60s) — slow to recover
- ❌ Circuit breaker without fallback — raw exception to client
- ❌ Fallback that calls the same protected resource — infinite loop

### Bulkhead
- ❌ Single bulkhead for TCP and REST — load from one affects the other
- ❌ Timeout simulation in main bulkhead — blocks slots for 35s
- ❌ Queue too large — messages get "old" in queue

### Backpressure
- ❌ `Thread.sleep()` to simulate backpressure — blocks event loop
- ❌ Ignore `socket.pause()` — can cause OOM with accumulated messages
- ❌ Never call `socket.resume()` — connection stays frozen permanently
