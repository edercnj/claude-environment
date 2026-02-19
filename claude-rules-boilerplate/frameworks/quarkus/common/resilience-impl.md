# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Quarkus — Resilience Implementation

> Extends: `core/09-resilience-principles.md`

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

### Why MicroProfile Fault Tolerance (NOT Resilience4j)

| Criterion | MP Fault Tolerance | Resilience4j |
|----------|-------------------|-------------|
| Quarkus Integration | Native (SmallRye) | Requires adapter |
| Configuration | `application.properties` | Programmatic or YAML |
| CDI-aware | Yes, automatic | No |
| Native build | Supported | Requires extra configuration |
| Standard | Jakarta EE / MicroProfile | Proprietary |
| Automatic Metrics | Yes (OpenTelemetry) | Requires bridge |

## Circuit Breaker

```java
@ApplicationScoped
public class PostgresPersistenceAdapter implements PersistencePort {

    private final TransactionRepository repository;

    @Inject
    public PostgresPersistenceAdapter(TransactionRepository repository) {
        this.repository = repository;
    }

    @Override
    @CircuitBreaker(requestVolumeThreshold = 10, failureRatio = 0.5, delay = 30000, successThreshold = 3)
    @Fallback(fallbackMethod = "saveFallback")
    public void save(Transaction transaction) {
        repository.persist(TransactionEntityMapper.toEntity(transaction));
    }

    private void saveFallback(Transaction transaction) {
        LOG.errorf("Circuit OPEN — cannot persist transaction STAN=%s, failing secure", transaction.stan());
        throw new PersistenceUnavailableException(transaction.stan());
    }

    @Override
    @CircuitBreaker(requestVolumeThreshold = 10, failureRatio = 0.5, delay = 30000, successThreshold = 3)
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

## Bulkhead + Timeout

```java
@ApplicationScoped
public class AuthorizeTransactionUseCase {

    @Bulkhead(value = 80, waitingTaskQueue = 20)
    @Timeout(value = 10000)
    @Fallback(fallbackMethod = "authorizeFallback")
    public TransactionResult authorize(IsoMessage request) {
        // normal processing
    }

    private TransactionResult authorizeFallback(IsoMessage request) {
        LOG.warnf("Fallback invoked — rejecting transaction MTI=%s", request.getMti());
        return TransactionResult.systemError("Processing failed");
    }
}
```

## Retry

```java
@Override
@Retry(maxRetries = 2, delay = 100, maxDuration = 2000, jitter = 50,
       retryOn = {SQLException.class, PersistenceException.class},
       abortOn = {ConstraintViolationException.class})
public Optional<Transaction> findByStanAndDate(String stan, String date) {
    return repository.findByStanAndDate(stan, date).map(TransactionEntityMapper::toDomain);
}

// NO @Retry — INSERT is not idempotent
@Override
public void save(Transaction transaction) {
    repository.persist(TransactionEntityMapper.toEntity(transaction));
}
```

## Rate Limiting (Bucket4j)

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
}
```

### REST Rate Limit Filter

```java
@Provider
@Priority(Priorities.AUTHENTICATION - 100)
public class RateLimitFilter implements ContainerRequestFilter {

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

## Vert.x Backpressure

```java
private final AtomicInteger pendingMessages = new AtomicInteger(0);

private void handleMessageBody(Buffer bodyBuffer, RecordParser parser, NetSocket socket, ConnectionContext context) {
    int pending = pendingMessages.incrementAndGet();

    if (pending > 10) {
        socket.pause();
        LOG.warnf("Backpressure activated for connection %s (pending=%d)", context.connectionId(), pending);
    }

    handler.process(bodyBuffer)
        .subscribe().with(
            response -> {
                socket.write(Buffer.buffer(frameMessage(response)));
                if (pendingMessages.decrementAndGet() <= 5) {
                    socket.resume();
                }
            },
            error -> {
                pendingMessages.decrementAndGet();
                handleProcessingError(socket, context, error);
            }
        );
}
```

## Graceful Degradation

```java
@ApplicationScoped
public class DegradationManager {

    private volatile DegradationLevel currentLevel = DegradationLevel.NORMAL;

    @Scheduled(every = "{simulator.resilience.degradation.evaluation-interval}")
    void evaluateDegradation() {
        var metrics = collectMetrics();
        var newLevel = calculateLevel(metrics);
        if (newLevel != currentLevel) {
            LOG.warnf("Degradation level changed: %s -> %s", currentLevel, newLevel);
            currentLevel = newLevel;
        }
    }

    public DegradationLevel getCurrentLevel() {
        return currentLevel;
    }
}
```

### DegradationHealthCheck

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

## ResilienceConfig (ConfigMapping)

```java
@ConfigMapping(prefix = "simulator.resilience")
public interface ResilienceConfig {

    RateLimitConfig rateLimit();
    DegradationConfig degradation();

    interface RateLimitConfig {
        @WithDefault("100") int restPerIp();
        @WithDefault("10") int restPost();
        @WithDefault("50") int tcpPerConnection();
        @WithDefault("5000") int tcpGlobal();
    }

    interface DegradationConfig {
        @WithDefault("5s") String evaluationInterval();
        @WithDefault("70") int cpuWarningThreshold();
        @WithDefault("85") int cpuCriticalThreshold();
        @WithDefault("200") int latencyWarningMs();
        @WithDefault("500") int latencyCriticalMs();
    }
}
```

## application.properties — Resilience

```properties
# Rate Limiting (Bucket4j)
simulator.resilience.rate-limit.rest-per-ip=100
simulator.resilience.rate-limit.rest-post=10
simulator.resilience.rate-limit.tcp-per-connection=50
simulator.resilience.rate-limit.tcp-global=5000

# Circuit Breaker (MicroProfile FT override via config)
PostgresPersistenceAdapter/save/CircuitBreaker/requestVolumeThreshold=10
PostgresPersistenceAdapter/save/CircuitBreaker/failureRatio=0.5
PostgresPersistenceAdapter/save/CircuitBreaker/delay=30000
PostgresPersistenceAdapter/save/CircuitBreaker/successThreshold=3

# Bulkhead
AuthorizeTransactionUseCase/authorize/Bulkhead/value=80
AuthorizeTransactionUseCase/authorize/Bulkhead/waitingTaskQueue=20

# Timeout (values in milliseconds — MP FT default unit)
AuthorizeTransactionUseCase/authorize/Timeout/value=10000

# Retry
PostgresPersistenceAdapter/findByStanAndDate/Retry/maxRetries=2
PostgresPersistenceAdapter/findByStanAndDate/Retry/delay=100
PostgresPersistenceAdapter/findByStanAndDate/Retry/jitter=50

# Degradation
simulator.resilience.degradation.evaluation-interval=5s
simulator.resilience.degradation.cpu-warning-threshold=70
simulator.resilience.degradation.cpu-critical-threshold=85
simulator.resilience.degradation.latency-warning-ms=200
simulator.resilience.degradation.latency-critical-ms=500
```

## Maven Dependencies

```xml
<!-- MicroProfile Fault Tolerance (includes SmallRye) -->
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

No additional dependencies for backpressure (Vert.x native) or health checks (SmallRye Health already included).

## Anti-Patterns

- Approve transaction when fallback is invoked — ALWAYS deny with system error
- Retry on non-idempotent operations (transaction INSERT)
- Retry without jitter — causes thundering herd
- Infinite retry — always define `maxRetries`
- Timeout longer than client timeout
- Circuit breaker on operations with natural fallback (e.g., cache miss)
- Resilience4j or other proprietary lib — use MicroProfile Fault Tolerance
- Single bulkhead for TCP and REST — load from one affects the other
- `Thread.sleep()` to simulate backpressure — blocks event loop
