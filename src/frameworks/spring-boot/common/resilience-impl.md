# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Spring Boot — Resilience Implementation (Resilience4j)

> Extends: `core/09-resilience-principles.md`
> All fail-secure, graceful degradation, and observability principles apply.

## Technology Stack

| Pattern | Technology | Justification |
|---------|-----------|---------------|
| Circuit Breaker | Resilience4j `@CircuitBreaker` | Native Spring Boot starter, Micrometer metrics |
| Retry | Resilience4j `@Retry` | YAML-configurable, annotation-driven |
| Timeout | Resilience4j `@TimeLimiter` | Integrates with CompletableFuture |
| Bulkhead | Resilience4j `@Bulkhead` | Semaphore or thread-pool isolation |
| Rate Limiting | Bucket4j (in-memory) | Token Bucket, high performance, no external dependency |
| Backpressure | Netty/NIO native | Zero overhead for TCP stack |
| Health/Degradation | Spring Actuator (custom HealthIndicator) | Exposes state via `/actuator/health` |

### Why Resilience4j (and NOT MicroProfile Fault Tolerance)

| Criterion | Resilience4j | MP Fault Tolerance |
|----------|-------------|-------------------|
| Spring Boot Integration | Native (spring-boot starter) | Requires adapter |
| Configuration | YAML (`application.yml`) | `application.properties` only |
| Metrics | Micrometer (native) | Requires bridge |
| Registry/Management | Programmatic registry access | Annotation-only |
| Community | Large Spring ecosystem | MicroProfile ecosystem |
| Rate Limiting | Built-in `@RateLimiter` | Not included |

## 1. Circuit Breaker

### Configuration (application.yml)

```yaml
resilience4j:
  circuitbreaker:
    configs:
      default:
        register-health-indicator: true
        sliding-window-type: COUNT_BASED
        sliding-window-size: 10
        minimum-number-of-calls: 5
        failure-rate-threshold: 50
        wait-duration-in-open-state: 30s
        permitted-number-of-calls-in-half-open-state: 3
        automatic-transition-from-open-to-half-open-enabled: true
    instances:
      db-write:
        base-config: default
        failure-rate-threshold: 50
        wait-duration-in-open-state: 30s
      db-read:
        base-config: default
        failure-rate-threshold: 50
        wait-duration-in-open-state: 30s
      decision-engine:
        base-config: default
        failure-rate-threshold: 30
        wait-duration-in-open-state: 15s
        sliding-window-size: 10
```

### Implementation

```java
@Repository
public class PostgresPersistenceAdapter implements PersistencePort {

    private static final Logger LOG = LoggerFactory.getLogger(PostgresPersistenceAdapter.class);

    private final TransactionJpaRepository repository;

    public PostgresPersistenceAdapter(TransactionJpaRepository repository) {
        this.repository = repository;
    }

    @Override
    @CircuitBreaker(name = "db-write", fallbackMethod = "saveFallback")
    public void save(Transaction transaction) {
        repository.save(TransactionEntityMapper.toEntity(transaction));
    }

    private void saveFallback(Transaction transaction, Throwable throwable) {
        LOG.error("Circuit OPEN (db-write) -- cannot persist transaction STAN={}, cause={}", transaction.stan(), throwable.getMessage());
        throw new PersistenceUnavailableException(transaction.stan());
    }

    @Override
    @CircuitBreaker(name = "db-read", fallbackMethod = "findFallback")
    @Retry(name = "db-read")
    public Optional<Transaction> findByStanAndDate(String stan, String date) {
        return repository.findByStanAndLocalDateTime(stan, date)
            .map(TransactionEntityMapper::toDomain);
    }

    private Optional<Transaction> findFallback(String stan, String date, Throwable throwable) {
        LOG.error("Circuit OPEN (db-read) -- cannot query transactions, returning empty. Cause={}", throwable.getMessage());
        return Optional.empty();
    }
}
```

### Circuit Breaker States

```
CLOSED (normal) --[failure ratio >= threshold]--> OPEN (rejects everything)
                                                      |
                                                  [delay expires]
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

### Behavior by State

| State | TCP (ISO 8583) | REST API |
|-------|---------------|----------|
| CLOSED | Normal processing | Normal processing |
| OPEN | RC 96 (System Error) | HTTP 503 + `Retry-After` |
| HALF_OPEN | Process 1 test message | Process 1 test request |

## 2. Retry

### Configuration

```yaml
resilience4j:
  retry:
    configs:
      default:
        max-attempts: 3
        wait-duration: 100ms
        enable-exponential-backoff: true
        exponential-backoff-multiplier: 2
        retry-exceptions:
          - java.sql.SQLException
          - org.springframework.dao.DataAccessResourceFailureException
          - java.net.SocketTimeoutException
        ignore-exceptions:
          - org.springframework.dao.DataIntegrityViolationException
          - jakarta.validation.ConstraintViolationException
    instances:
      db-read:
        base-config: default
        max-attempts: 2
        wait-duration: 100ms
      db-connection:
        base-config: default
        max-attempts: 3
        wait-duration: 500ms
```

### Retry Rules

| Operation | Retry? | Max Attempts | Reason |
|-----------|--------|-------------|--------|
| DB read (SELECT) | Yes | 2 | Idempotent, transient failures |
| DB connection acquire | Yes | 3 | Pool exhaustion is transient |
| DB write (INSERT) | **NO** | -- | Not idempotent |
| ISO message processing | **NO** | -- | Not idempotent |
| Health check query | Yes | 3 | Transient probe failures |

```java
// CORRECT — Retry on idempotent read
@Retry(name = "db-read", fallbackMethod = "findFallback")
public Optional<Transaction> findByStanAndDate(String stan, String date) {
    return repository.findByStanAndLocalDateTime(stan, date)
        .map(TransactionEntityMapper::toDomain);
}

// CORRECT — NO retry on non-idempotent write
// No @Retry annotation
public void save(Transaction transaction) {
    repository.save(TransactionEntityMapper.toEntity(transaction));
}
```

## 3. Bulkhead (Load Isolation)

### Configuration

```yaml
resilience4j:
  bulkhead:
    configs:
      default:
        max-concurrent-calls: 80
        max-wait-duration: 500ms
    instances:
      tcp-processing:
        max-concurrent-calls: 80
        max-wait-duration: 500ms
      rest-processing:
        max-concurrent-calls: 20
        max-wait-duration: 500ms
      db-operations:
        max-concurrent-calls: 15
        max-wait-duration: 200ms

  thread-pool-bulkhead:
    instances:
      timeout-simulation:
        max-thread-pool-size: 10
        core-thread-pool-size: 5
        queue-capacity: 5
```

### Implementation

```java
@Service
public class AuthorizeTransactionUseCase {

    private static final Logger LOG = LoggerFactory.getLogger(AuthorizeTransactionUseCase.class);

    private final PersistencePort persistencePort;
    private final CentsDecisionEngine decisionEngine;

    public AuthorizeTransactionUseCase(PersistencePort persistencePort, CentsDecisionEngine decisionEngine) {
        this.persistencePort = persistencePort;
        this.decisionEngine = decisionEngine;
    }

    @Bulkhead(name = "tcp-processing", fallbackMethod = "authorizeFallback")
    @TimeLimiter(name = "tcp-processing", fallbackMethod = "timeoutFallback")
    public TransactionResult authorize(IsoMessage request) {
        var amount = extractAmount(request);
        var responseCode = decisionEngine.decide(amount);
        var transaction = buildTransaction(request, responseCode);
        persistencePort.save(transaction);
        return buildResponse(request, responseCode, transaction);
    }

    private TransactionResult authorizeFallback(IsoMessage request, Throwable throwable) {
        LOG.warn("Bulkhead full -- rejecting transaction MTI={}, cause={}", request.getMti(), throwable.getMessage());
        return TransactionResult.systemError("Bulkhead capacity exceeded");
    }

    private TransactionResult timeoutFallback(IsoMessage request, Throwable throwable) {
        LOG.error("Processing timeout -- MTI={} STAN={}", request.getMti(), request.getStan());
        return TransactionResult.systemError("Processing timeout");
    }
}
```

## 4. TimeLimiter (Timeout)

### Configuration

```yaml
resilience4j:
  timelimiter:
    configs:
      default:
        timeout-duration: 10s
        cancel-running-future: true
    instances:
      tcp-processing:
        timeout-duration: 10s
      rest-processing:
        timeout-duration: 30s
      db-query:
        timeout-duration: 5s
```

## 5. Rate Limiting with Bucket4j

```java
@Component
public class RateLimiter {

    private static final Logger LOG = LoggerFactory.getLogger(RateLimiter.class);
    private static final int MAX_BUCKETS = 10_000;
    private static final Duration IDLE_EVICTION_THRESHOLD = Duration.ofMinutes(5);

    private final ConcurrentHashMap<String, TimestampedBucket> buckets = new ConcurrentHashMap<>();
    private final Bandwidth defaultBandwidth;

    public RateLimiter(RateLimitProperties config) {
        this.defaultBandwidth = Bandwidth.classic(
            config.tcpPerConnection(),
            Refill.intervally(config.tcpPerConnection(), Duration.ofSeconds(1))
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

    public void evict(String key) {
        buckets.remove(key);
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

### REST API Filter (OncePerRequestFilter)

```java
@Component
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
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setHeader("Retry-After", String.valueOf(result.retryAfterSeconds()));
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            var problemDetail = ProblemDetail.tooManyRequests("Rate limit exceeded", request.getRequestURI());
            objectMapper.writeValue(response.getOutputStream(), problemDetail);
            return;
        }

        filterChain.doFilter(request, response);
    }

    private String extractClientIp(HttpServletRequest request) {
        var xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isBlank()) {
            return xForwardedFor.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return request.getRequestURI().startsWith("/actuator");
    }
}
```

## 6. Graceful Degradation

### Degradation Levels

| Level | Condition | Actions |
|-------|---------|-------|
| **NORMAL** | CPU < 70%, p99 < 200ms, circuits closed | Everything enabled |
| **WARNING** | CPU 70-85% OR p99 200-500ms | Reduce rate limit 50%, disable DEBUG logs |
| **CRITICAL** | CPU > 85% OR p99 > 500ms OR circuit open | Reject new TCP connections, process existing only |
| **EMERGENCY** | DB down OR multiple circuits open | Only echo test (1804->1814), reject all with RC 96 |

### Implementation

```java
@Component
public class DegradationManager {

    private static final Logger LOG = LoggerFactory.getLogger(DegradationManager.class);

    private final DegradationProperties config;
    private volatile DegradationLevel currentLevel = DegradationLevel.NORMAL;

    public DegradationManager(DegradationProperties config) {
        this.config = config;
    }

    public DegradationLevel getCurrentLevel() {
        return currentLevel;
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

public enum DegradationLevel {
    NORMAL, WARNING, CRITICAL, EMERGENCY
}
```

### Degradation Health Indicator

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

## 7. Configuration Properties

```java
@ConfigurationProperties(prefix = "simulator.resilience.rate-limit")
public record RateLimitProperties(
    int restPerIp,
    int restPost,
    int tcpPerConnection,
    int tcpGlobal
) {
    public RateLimitProperties {
        if (restPerIp <= 0) restPerIp = 100;
        if (restPost <= 0) restPost = 10;
        if (tcpPerConnection <= 0) tcpPerConnection = 50;
        if (tcpGlobal <= 0) tcpGlobal = 5000;
    }
}

@ConfigurationProperties(prefix = "simulator.resilience.degradation")
public record DegradationProperties(
    long evaluationIntervalMs,
    int cpuWarningThreshold,
    int cpuCriticalThreshold,
    int latencyWarningMs,
    int latencyCriticalMs
) {
    public DegradationProperties {
        if (evaluationIntervalMs <= 0) evaluationIntervalMs = 5000;
        if (cpuWarningThreshold <= 0) cpuWarningThreshold = 70;
        if (cpuCriticalThreshold <= 0) cpuCriticalThreshold = 85;
        if (latencyWarningMs <= 0) latencyWarningMs = 200;
        if (latencyCriticalMs <= 0) latencyCriticalMs = 500;
    }
}
```

## 8. Maven Dependencies

```xml
<!-- Resilience4j Spring Boot Starter -->
<dependency>
    <groupId>io.github.resilience4j</groupId>
    <artifactId>resilience4j-spring-boot3</artifactId>
</dependency>

<!-- Resilience4j Micrometer metrics -->
<dependency>
    <groupId>io.github.resilience4j</groupId>
    <artifactId>resilience4j-micrometer</artifactId>
</dependency>

<!-- Spring Boot AOP (required for annotations) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-aop</artifactId>
</dependency>

<!-- Bucket4j (Rate Limiting) -->
<dependency>
    <groupId>com.bucket4j</groupId>
    <artifactId>bucket4j-core</artifactId>
    <version>${bucket4j.version}</version>
</dependency>
```

## Anti-Patterns (FORBIDDEN)

```java
// FORBIDDEN — Fallback approves transaction
private TransactionResult decideFallback(BigDecimal amount, Throwable t) {
    return TransactionResult.approved();  // DANGER: failure = approval
}

// FORBIDDEN — Retry on non-idempotent INSERT
@Retry(name = "db-write")
public void save(Transaction transaction) { ... }

// FORBIDDEN — Retry without jitter (causes thundering herd)
// Always use exponential backoff with randomized-wait in YAML

// FORBIDDEN — Single bulkhead for TCP and REST
@Bulkhead(name = "global")  // Separate tcp-processing and rest-processing

// FORBIDDEN — Timeout simulation in main bulkhead
@Bulkhead(name = "tcp-processing")
public TransactionResult authorizeWithTimeout(IsoMessage request) {
    Thread.sleep(35_000);  // Blocks main pool for 35 seconds!
}

// FORBIDDEN — Circuit breaker with too low threshold
resilience4j.circuitbreaker.instances.myCircuit.minimum-number-of-calls: 1  // Opens on single failure

// FORBIDDEN — Fallback that calls the same protected resource
private void saveFallback(Transaction tx, Throwable t) {
    repository.save(tx);  // Same resource that is circuit-broken!
}
```

## Resilience Exception Handling in REST

Add Resilience4j exceptions to the global exception handler:

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(CallNotPermittedException.class)
    public ResponseEntity<ProblemDetail> handleCircuitBreakerOpen(CallNotPermittedException exception, HttpServletRequest request) {
        var problemDetail = ProblemDetail.serviceUnavailable(
            "Service temporarily unavailable", request.getRequestURI());
        return ResponseEntity.status(503)
            .header("Retry-After", "30")
            .body(problemDetail);
    }

    @ExceptionHandler(BulkheadFullException.class)
    public ResponseEntity<ProblemDetail> handleBulkheadFull(BulkheadFullException exception, HttpServletRequest request) {
        var problemDetail = ProblemDetail.serviceUnavailable(
            "Service at capacity", request.getRequestURI());
        return ResponseEntity.status(503)
            .header("Retry-After", "5")
            .body(problemDetail);
    }

    @ExceptionHandler(RequestNotPermitted.class)
    public ResponseEntity<ProblemDetail> handleRateLimitExceeded(RequestNotPermitted exception, HttpServletRequest request) {
        var problemDetail = ProblemDetail.tooManyRequests(
            "Rate limit exceeded", request.getRequestURI());
        return ResponseEntity.status(429)
            .header("Retry-After", "1")
            .body(problemDetail);
    }
}
```
