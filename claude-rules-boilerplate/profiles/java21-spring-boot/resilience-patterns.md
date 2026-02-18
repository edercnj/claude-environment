# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 21 + Spring Boot — Resilience Patterns

> Extends: `core/09-resilience-principles.md`

## Technology Stack

| Pattern | Technology | Justification |
|---------|-----------|---------------|
| Circuit Breaker | Resilience4j (`@CircuitBreaker`) | Native Spring Boot integration, Micrometer metrics |
| Retry | Resilience4j (`@Retry`) | Configuration via `application.yml` |
| Timeout | Resilience4j (`@TimeLimiter`) | Declarative timeout control |
| Bulkhead | Resilience4j (`@Bulkhead`) | Isolation via semaphore or thread pool |
| Rate Limiting | Resilience4j (`@RateLimiter`) + Bucket4j | Declarative + programmatic options |
| Fallback | Resilience4j (fallbackMethod) | Declarative degradation |
| Health/Degradation | Spring Boot Actuator (custom `HealthIndicator`) | Exposes state via `/actuator/health` |

### Why Resilience4j (NOT MicroProfile Fault Tolerance)

| Criterion | Resilience4j | MP Fault Tolerance |
|----------|-------------|-------------------|
| Spring Boot Integration | Native (spring-cloud-circuitbreaker) | Requires SmallRye adapter |
| Configuration | `application.yml` (type-safe) | Programmatic or annotation |
| Monitoring | Micrometer native (auto-exposed) | Requires bridge |
| Rate Limiting | Built-in `@RateLimiter` | Not included |
| Actuator endpoints | `/actuator/circuitbreakers`, `/actuator/retries` | Not available |
| Community | Large Spring ecosystem | Jakarta EE focused |

## Circuit Breaker

```java
@Service
public class PostgresPersistenceAdapter implements PersistencePort {

    private static final Logger LOG = LoggerFactory.getLogger(PostgresPersistenceAdapter.class);

    private final TransactionRepository repository;

    public PostgresPersistenceAdapter(TransactionRepository repository) {
        this.repository = repository;
    }

    @Override
    @CircuitBreaker(name = "dbWrite", fallbackMethod = "saveFallback")
    public void save(Transaction transaction) {
        repository.save(TransactionEntityMapper.toEntity(transaction));
    }

    private void saveFallback(Transaction transaction, Throwable throwable) {
        LOG.error("Circuit OPEN - cannot persist transaction STAN={}, failing secure", transaction.stan(), throwable);
        throw new PersistenceUnavailableException(transaction.stan());
    }

    @Override
    @CircuitBreaker(name = "dbRead", fallbackMethod = "findFallback")
    public Optional<Transaction> findByStanAndDate(String stan, String date) {
        return repository.findByStanAndDate(stan, date).map(TransactionEntityMapper::toDomain);
    }

    private Optional<Transaction> findFallback(String stan, String date, Throwable throwable) {
        LOG.error("Circuit OPEN - cannot query transactions, returning empty", throwable);
        return Optional.empty();
    }
}
```

### Circuit Breaker States

```
CLOSED (normal) --[failure ratio >= threshold]--> OPEN (rejects everything)
                                                      |
                                                  [wait duration expires]
                                                      |
                                                      v
                                               HALF_OPEN (tests)
                                                      |
                                     +----------------+----------------+
                               [success >= N]                    [failure]
                                     |                              |
                                     v                              v
                                  CLOSED                          OPEN
```

## Bulkhead + TimeLimiter

```java
@Service
public class AuthorizeTransactionUseCase {

    private static final Logger LOG = LoggerFactory.getLogger(AuthorizeTransactionUseCase.class);

    @Bulkhead(name = "tcpProcessing", fallbackMethod = "authorizeFallback")
    @TimeLimiter(name = "processing", fallbackMethod = "timeoutFallback")
    public CompletableFuture<TransactionResult> authorize(IsoMessage request) {
        return CompletableFuture.supplyAsync(() -> {
            // normal processing
            return processTransaction(request);
        });
    }

    private CompletableFuture<TransactionResult> authorizeFallback(IsoMessage request, Throwable throwable) {
        LOG.warn("Bulkhead full - rejecting transaction MTI={}", request.getMti(), throwable);
        return CompletableFuture.completedFuture(TransactionResult.systemError("Bulkhead capacity exceeded"));
    }

    private CompletableFuture<TransactionResult> timeoutFallback(IsoMessage request, Throwable throwable) {
        LOG.error("Processing timeout - MTI={} STAN={}", request.getMti(), request.getStan(), throwable);
        return CompletableFuture.completedFuture(TransactionResult.systemError("Processing timeout"));
    }
}
```

## Retry

```java
@Override
@Retry(name = "dbRead", fallbackMethod = "findFallback")
public Optional<Transaction> findByStanAndDate(String stan, String date) {
    return repository.findByStanAndDate(stan, date).map(TransactionEntityMapper::toDomain);
}

// NO @Retry - INSERT is not idempotent
@Override
public void save(Transaction transaction) {
    repository.save(TransactionEntityMapper.toEntity(transaction));
}
```

### Retry Rules

- NEVER retry on non-idempotent operations (transaction INSERT)
- NEVER retry on business errors (validation, RC != 00)
- ONLY retry on transient failures (connection reset, network timeout)
- ALWAYS configure `ignoreExceptions` for permanent failures

## Rate Limiting (Bucket4j)

Bucket4j is framework-agnostic and works identically to the Quarkus implementation:

```java
@Component
public class RateLimiter {

    private static final Logger LOG = LoggerFactory.getLogger(RateLimiter.class);
    private static final int MAX_BUCKETS = 10_000;
    private static final Duration IDLE_EVICTION_THRESHOLD = Duration.ofMinutes(5);

    private final ConcurrentHashMap<String, TimestampedBucket> buckets = new ConcurrentHashMap<>();
    private final Bandwidth defaultBandwidth;

    public RateLimiter(SimulatorProperties properties) {
        this.defaultBandwidth = Bandwidth.classic(
            properties.getResilience().getRateLimit().getTcpPerConnection(),
            Refill.intervally(
                properties.getResilience().getRateLimit().getTcpPerConnection(),
                Duration.ofSeconds(1)
            )
        );
    }

    public ConsumptionResult tryConsume(String key) {
        if (buckets.size() >= MAX_BUCKETS && !buckets.containsKey(key)) {
            LOG.warn("Rate limiter bucket limit reached ({}), rejecting new key: {}", MAX_BUCKETS, key);
            return new ConsumptionResult(false, Duration.ofSeconds(1).toNanos());
        }
        var timestamped = buckets.computeIfAbsent(key, k ->
            new TimestampedBucket(Bucket.builder().addLimit(defaultBandwidth).build()));
        timestamped.touch();
        var probe = timestamped.bucket().tryConsumeAndReturnRemaining(1);
        return new ConsumptionResult(probe.isConsumed(), probe.getNanosToWaitForRefill());
    }

    @Scheduled(fixedRate = 60_000)
    void evictIdleBuckets() {
        var cutoff = Instant.now().minus(IDLE_EVICTION_THRESHOLD);
        int before = buckets.size();
        buckets.entrySet().removeIf(e -> e.getValue().lastAccess().isBefore(cutoff));
        int evicted = before - buckets.size();
        if (evicted > 0) {
            LOG.info("Evicted {} idle rate limit buckets (remaining={})", evicted, buckets.size());
        }
    }

    public record ConsumptionResult(boolean consumed, long nanosToWaitForRefill) {
        public long retryAfterSeconds() {
            return Math.max(1, TimeUnit.NANOSECONDS.toSeconds(nanosToWaitForRefill));
        }
    }
}
```

### REST Rate Limit Filter (OncePerRequestFilter)

```java
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RateLimitFilter extends OncePerRequestFilter {

    private static final Logger LOG = LoggerFactory.getLogger(RateLimitFilter.class);

    private final RateLimiter rateLimiter;
    private final ObjectMapper objectMapper;

    public RateLimitFilter(RateLimiter rateLimiter, ObjectMapper objectMapper) {
        this.rateLimiter = rateLimiter;
        this.objectMapper = objectMapper;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain) throws ServletException, IOException {
        var clientIp = extractClientIp(request);
        var result = rateLimiter.tryConsume("rest:" + clientIp);
        if (!result.consumed()) {
            LOG.warn("Rate limit exceeded for IP: {}", clientIp);
            response.setStatus(429);
            response.setHeader("Retry-After", String.valueOf(result.retryAfterSeconds()));
            response.setContentType("application/json");
            objectMapper.writeValue(response.getOutputStream(),
                ProblemDetail.tooManyRequests("Rate limit exceeded", request.getRequestURI()));
            return;
        }
        filterChain.doFilter(request, response);
    }

    private String extractClientIp(HttpServletRequest request) {
        var forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
```

## Graceful Degradation

```java
@Component
public class DegradationManager {

    private static final Logger LOG = LoggerFactory.getLogger(DegradationManager.class);

    private volatile DegradationLevel currentLevel = DegradationLevel.NORMAL;
    private final SimulatorProperties properties;

    public DegradationManager(SimulatorProperties properties) {
        this.properties = properties;
    }

    @Scheduled(fixedDelayString = "${simulator.resilience.degradation.evaluation-interval-ms:5000}")
    void evaluateDegradation() {
        var metrics = collectMetrics();
        var newLevel = calculateLevel(metrics);
        if (newLevel != currentLevel) {
            LOG.warn("Degradation level changed: {} -> {}", currentLevel, newLevel);
            currentLevel = newLevel;
        }
    }

    public DegradationLevel getCurrentLevel() {
        return currentLevel;
    }

    private DegradationLevel calculateLevel(SystemMetrics metrics) {
        var config = properties.getResilience().getDegradation();
        if (metrics.dbCircuitOpen() || metrics.multipleCircuitsOpen()) {
            return DegradationLevel.EMERGENCY;
        }
        if (metrics.cpuUsage() > config.getCpuCriticalThreshold()
                || metrics.p99LatencyMs() > config.getLatencyCriticalMs()
                || metrics.anyCircuitOpen()) {
            return DegradationLevel.CRITICAL;
        }
        if (metrics.cpuUsage() > config.getCpuWarningThreshold()
                || metrics.p99LatencyMs() > config.getLatencyWarningMs()) {
            return DegradationLevel.WARNING;
        }
        return DegradationLevel.NORMAL;
    }
}
```

### DegradationHealthIndicator

```java
@Component
public class DegradationHealthIndicator implements HealthIndicator {

    private final DegradationManager degradationManager;

    public DegradationHealthIndicator(DegradationManager degradationManager) {
        this.degradationManager = degradationManager;
    }

    @Override
    public Health health() {
        var level = degradationManager.getCurrentLevel();
        return switch (level) {
            case NORMAL, WARNING -> Health.up()
                .withDetail("level", level.name())
                .build();
            case CRITICAL -> Health.up()
                .withDetail("level", level.name())
                .withDetail("warning", "system under high load")
                .build();
            case EMERGENCY -> Health.down()
                .withDetail("level", level.name())
                .withDetail("reason", "emergency degradation active")
                .build();
        };
    }
}
```

## Resilience4j Configuration (application.yml)

```yaml
resilience4j:
  circuitbreaker:
    instances:
      dbWrite:
        registerHealthIndicator: true
        slidingWindowSize: 10
        failureRateThreshold: 50
        waitDurationInOpenState: 30s
        permittedNumberOfCallsInHalfOpenState: 3
        slidingWindowType: COUNT_BASED
        minimumNumberOfCalls: 10
      dbRead:
        registerHealthIndicator: true
        slidingWindowSize: 10
        failureRateThreshold: 50
        waitDurationInOpenState: 30s
        permittedNumberOfCallsInHalfOpenState: 3
      decisionEngine:
        slidingWindowSize: 10
        failureRateThreshold: 30
        waitDurationInOpenState: 15s

  retry:
    instances:
      dbRead:
        maxAttempts: 3
        waitDuration: 100ms
        enableExponentialBackoff: true
        exponentialBackoffMultiplier: 2
        enableRandomizedWait: true
        randomizedWaitFactor: 0.5
        retryExceptions:
          - java.sql.SQLException
          - jakarta.persistence.PersistenceException
        ignoreExceptions:
          - jakarta.validation.ConstraintViolationException

  timelimiter:
    instances:
      processing:
        timeoutDuration: 10s
        cancelRunningFuture: true

  bulkhead:
    instances:
      tcpProcessing:
        maxConcurrentCalls: 80
        maxWaitDuration: 500ms
      restProcessing:
        maxConcurrentCalls: 20
        maxWaitDuration: 300ms
      dbOperations:
        maxConcurrentCalls: 15
        maxWaitDuration: 200ms

  ratelimiter:
    instances:
      restApi:
        limitForPeriod: 100
        limitRefreshPeriod: 1s
        timeoutDuration: 0
        registerHealthIndicator: true

# Custom resilience properties
simulator:
  resilience:
    rate-limit:
      rest-per-ip: 100
      rest-post: 10
      tcp-per-connection: 50
      tcp-global: 5000
    degradation:
      evaluation-interval-ms: 5000
      cpu-warning-threshold: 70
      cpu-critical-threshold: 85
      latency-warning-ms: 200
      latency-critical-ms: 500
```

## Configuration Properties Class

```java
@ConfigurationProperties(prefix = "simulator")
public class SimulatorProperties {

    private ResilienceProperties resilience = new ResilienceProperties();

    public ResilienceProperties getResilience() { return resilience; }
    public void setResilience(ResilienceProperties resilience) { this.resilience = resilience; }

    public static class ResilienceProperties {
        private RateLimitProperties rateLimit = new RateLimitProperties();
        private DegradationProperties degradation = new DegradationProperties();

        // getters and setters
    }

    public static class RateLimitProperties {
        private int restPerIp = 100;
        private int restPost = 10;
        private int tcpPerConnection = 50;
        private int tcpGlobal = 5000;

        // getters and setters
    }

    public static class DegradationProperties {
        private long evaluationIntervalMs = 5000;
        private int cpuWarningThreshold = 70;
        private int cpuCriticalThreshold = 85;
        private int latencyWarningMs = 200;
        private int latencyCriticalMs = 500;

        // getters and setters
    }
}
```

## Actuator Endpoints for Resilience

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,circuitbreakers,retries,ratelimiters,bulkheads
  endpoint:
    health:
      show-details: always
  health:
    circuitbreakers:
      enabled: true
```

Available monitoring endpoints:
- `/actuator/circuitbreakers` — all circuit breaker states
- `/actuator/circuitbreakers/{name}` — specific circuit breaker
- `/actuator/retries` — retry configuration and events
- `/actuator/ratelimiters` — rate limiter states
- `/actuator/bulkheads` — bulkhead states

## Maven Dependencies

```xml
<!-- Resilience4j with Spring Boot starter -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-circuitbreaker-resilience4j</artifactId>
</dependency>

<!-- Resilience4j Spring Boot 3 starter (alternative, more complete) -->
<dependency>
    <groupId>io.github.resilience4j</groupId>
    <artifactId>resilience4j-spring-boot3</artifactId>
    <version>${resilience4j.version}</version>
</dependency>

<!-- Bucket4j (Rate Limiting — framework-agnostic) -->
<dependency>
    <groupId>com.bucket4j</groupId>
    <artifactId>bucket4j-core</artifactId>
    <version>${bucket4j.version}</version>
</dependency>

<!-- AOP support (required by Resilience4j annotations) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-aop</artifactId>
</dependency>
```

## Anti-Patterns

- Approve transaction when fallback is invoked — ALWAYS deny with system error (RC 96)
- Retry on non-idempotent operations (transaction INSERT)
- Retry without jitter — causes thundering herd
- Infinite retry — always define `maxAttempts`
- Timeout longer than client timeout
- Circuit breaker on operations with natural fallback (e.g., cache miss)
- MicroProfile Fault Tolerance in Spring Boot — use Resilience4j
- Single bulkhead for TCP and REST — load from one affects the other
- `Thread.sleep()` to simulate backpressure — blocks thread pool
- Missing `spring-boot-starter-aop` — Resilience4j annotations silently ignored
- Fallback method with wrong signature — must match original + Throwable parameter
