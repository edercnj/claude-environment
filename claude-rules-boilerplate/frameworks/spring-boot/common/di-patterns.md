# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Spring Boot — Dependency Injection Patterns

> Extends the base Java coding conventions. All Clean Code, SOLID, and naming rules apply.

## Constructor Injection (Preferred)

Spring Boot automatically uses constructor injection when a class has a **single constructor**. No `@Autowired` annotation is needed.

```java
@Service
public class TransactionService {

    private final TransactionRepository repository;
    private final AuthorizationEngine engine;
    private final TransactionMetrics metrics;

    public TransactionService(TransactionRepository repository, AuthorizationEngine engine, TransactionMetrics metrics) {
        this.repository = repository;
        this.engine = engine;
        this.metrics = metrics;
    }
}
```

If a class has **multiple constructors**, annotate the preferred one with `@Autowired`:

```java
@Service
public class NotificationService {

    private final EmailSender emailSender;
    private final TemplateEngine templateEngine;

    @Autowired
    public NotificationService(EmailSender emailSender, TemplateEngine templateEngine) {
        this.emailSender = emailSender;
        this.templateEngine = templateEngine;
    }

    public NotificationService(EmailSender emailSender) {
        this(emailSender, new DefaultTemplateEngine());
    }
}
```

## Stereotype Annotations

| Annotation | Purpose | Layer |
|-----------|---------|-------|
| `@Service` | Business logic, use cases | Application / Domain |
| `@Component` | Generic Spring-managed bean | Any |
| `@Repository` | Data access, persistence | Adapter (outbound) |
| `@RestController` | REST endpoint | Adapter (inbound) |
| `@Configuration` | Bean factory definitions | Config |

```java
// Application layer — orchestration
@Service
public class AuthorizeTransactionUseCase {

    private final PersistencePort persistencePort;
    private final CentsDecisionEngine decisionEngine;

    public AuthorizeTransactionUseCase(PersistencePort persistencePort, CentsDecisionEngine decisionEngine) {
        this.persistencePort = persistencePort;
        this.decisionEngine = decisionEngine;
    }

    public TransactionResult authorize(IsoMessage request) {
        var amount = extractAmount(request);
        var responseCode = decisionEngine.decide(amount);
        var transaction = buildTransaction(request, responseCode);
        persistencePort.save(transaction);
        return buildResponse(request, responseCode, transaction);
    }
}

// Domain layer — engine (no Spring annotations if pure domain)
@Component
public class CentsDecisionEngine {

    private static final String RESPONSE_APPROVED = "00";

    public String decide(BigDecimal amount) {
        int cents = amount.remainder(BigDecimal.ONE).movePointRight(2).intValue();
        return switch (cents) {
            case 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
                 11, 12, 13, 15, 16, 17, 18, 19, 20,
                 21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
                 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
                 41, 42, 44, 45, 46, 47, 48, 49, 50 -> RESPONSE_APPROVED;
            case 51 -> "51";
            case 14 -> "14";
            case 43 -> "43";
            case 57 -> "57";
            case 96 -> "96";
            default -> "05";
        };
    }
}

// Outbound adapter — persistence
@Repository
public class PostgresPersistenceAdapter implements PersistencePort {

    private final TransactionJpaRepository repository;

    public PostgresPersistenceAdapter(TransactionJpaRepository repository) {
        this.repository = repository;
    }

    @Override
    public void save(Transaction transaction) {
        repository.save(TransactionEntityMapper.toEntity(transaction));
    }

    @Override
    public Optional<Transaction> findByStanAndDate(String stan, String date) {
        return repository.findByStanAndLocalDateTime(stan, date)
            .map(TransactionEntityMapper::toDomain);
    }
}
```

## Lombok Usage

Lombok is **allowed but optional** in Spring Boot projects. It MUST NOT be used on Records.

```java
// Allowed — Lombok on service classes to reduce boilerplate
@Service
@RequiredArgsConstructor
public class MerchantService {

    private final MerchantRepository repository;
    private final MerchantValidator validator;

    public Merchant createMerchant(CreateMerchantRequest request) {
        validator.validate(request);
        var merchant = MerchantDtoMapper.toDomain(request);
        return repository.save(MerchantEntityMapper.toEntity(merchant));
    }
}

// FORBIDDEN — Lombok on Records (Records already have accessors/constructors)
// @Data  <-- NEVER on Records
public record MerchantResponse(Long id, String mid, String name) {}
```

| Lombok Annotation | Allowed? | Notes |
|-------------------|----------|-------|
| `@RequiredArgsConstructor` | Yes | Generates constructor for `final` fields |
| `@Slf4j` / `@Log` | Yes | Generates logger field |
| `@Builder` | Yes | On non-Record classes only |
| `@Data` | No | Use Records for DTOs/VOs |
| `@Getter`/`@Setter` | Sparingly | Prefer Records or manual getters |
| `@Value` (Lombok) | No | Use Java Records instead |

## @Qualifier for Multiple Implementations

When multiple beans implement the same interface, use `@Qualifier` to disambiguate:

```java
public interface NotificationSender {
    void send(String recipient, String message);
}

@Service
@Qualifier("email")
public class EmailNotificationSender implements NotificationSender {

    @Override
    public void send(String recipient, String message) {
        // Send via email
    }
}

@Service
@Qualifier("sms")
public class SmsNotificationSender implements NotificationSender {

    @Override
    public void send(String recipient, String message) {
        // Send via SMS
    }
}

@Service
public class AlertService {

    private final NotificationSender emailSender;
    private final NotificationSender smsSender;

    public AlertService(@Qualifier("email") NotificationSender emailSender, @Qualifier("sms") NotificationSender smsSender) {
        this.emailSender = emailSender;
        this.smsSender = smsSender;
    }
}
```

## @Primary for Default Implementation

Use `@Primary` when one implementation should be the default:

```java
public interface TransactionHandler {
    boolean supports(String mti);
    TransactionResult process(IsoMessage request);
}

@Service
@Primary
public class DebitSaleHandler implements TransactionHandler {

    @Override
    public boolean supports(String mti) {
        return "1200".equals(mti);
    }

    @Override
    public TransactionResult process(IsoMessage request) {
        // Default handler logic
        return TransactionResult.approved();
    }
}

@Service
public class EchoTestHandler implements TransactionHandler {

    @Override
    public boolean supports(String mti) {
        return "1804".equals(mti);
    }

    @Override
    public TransactionResult process(IsoMessage request) {
        return TransactionResult.echoResponse();
    }
}
```

## @Profile for Conditional Beans

Activate beans based on the Spring profile:

```java
@Service
@Profile("dev")
public class InMemoryPersistenceAdapter implements PersistencePort {

    private final Map<String, Transaction> store = new ConcurrentHashMap<>();

    @Override
    public void save(Transaction transaction) {
        store.put(transaction.stan(), transaction);
    }

    @Override
    public Optional<Transaction> findByStanAndDate(String stan, String date) {
        return Optional.ofNullable(store.get(stan));
    }
}

@Service
@Profile("!dev")
public class PostgresPersistenceAdapter implements PersistencePort {
    // Real PostgreSQL implementation
}
```

## @ConditionalOnProperty for Feature Flags

Enable beans based on configuration properties:

```java
@Service
@ConditionalOnProperty(name = "simulator.features.timeout-simulation.enabled", havingValue = "true", matchIfMissing = false)
public class TimeoutSimulationService {

    private final SimulatorConfig config;

    public TimeoutSimulationService(SimulatorConfig config) {
        this.config = config;
    }

    public void simulateTimeout(String tid) {
        int delaySeconds = config.getFeatures().getTimeoutSimulation().getDelaySeconds();
        try {
            Thread.sleep(delaySeconds * 1000L);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
```

Other conditional annotations:

| Annotation | Condition |
|-----------|-----------|
| `@ConditionalOnProperty` | Property value matches |
| `@ConditionalOnMissingBean` | No other bean of same type |
| `@ConditionalOnClass` | Class on classpath |
| `@ConditionalOnBean` | Another bean exists |

## @Configuration for Bean Factories

Use `@Configuration` for beans that need complex initialization:

```java
@Configuration
public class MessageRoutingConfig {

    @Bean
    public MessageRouter messageRouter(List<TransactionHandler> handlers) {
        return new MessageRouter(handlers);
    }

    @Bean
    public ObjectMapper objectMapper() {
        return new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .setSerializationInclusion(JsonInclude.Include.NON_NULL)
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    }
}
```

## Anti-Patterns (FORBIDDEN)

```java
// FORBIDDEN — Field injection
@Service
public class TransactionService {
    @Autowired
    private TransactionRepository repository;  // No constructor, field injection
}

// FORBIDDEN — Circular dependencies
@Service
public class ServiceA {
    public ServiceA(ServiceB serviceB) { ... }
}

@Service
public class ServiceB {
    public ServiceB(ServiceA serviceA) { ... }  // Circular!
}

// FORBIDDEN — @Autowired on single constructor (redundant)
@Service
public class TransactionService {
    @Autowired  // Unnecessary, Spring auto-detects single constructor
    public TransactionService(TransactionRepository repository) { ... }
}

// FORBIDDEN — Using @Component for everything
@Component  // Should be @Service for business logic
public class TransactionService { ... }

@Component  // Should be @Repository for data access
public class TransactionDao { ... }

// FORBIDDEN — Mutable state in singletons
@Service
public class TransactionCounter {
    private int count = 0;  // Shared mutable state, NOT thread-safe
    public void increment() { count++; }
}

// FORBIDDEN — Lombok @Data on Records
@Data  // Records already have accessors
public record MerchantResponse(Long id, String mid) {}

// FORBIDDEN — new keyword for managed beans
@RestController
public class MerchantController {
    public ResponseEntity<Merchant> get() {
        var service = new MerchantService();  // Not managed by Spring!
        return ResponseEntity.ok(service.findAll());
    }
}
```

## Decision Matrix

| Scenario | Pattern |
|---------|---------|
| Single implementation | Direct constructor injection |
| Multiple implementations, need all | `List<T>` injection |
| Multiple implementations, need one | `@Qualifier` |
| Default with override | `@Primary` + `@Qualifier` |
| Environment-specific | `@Profile` |
| Feature flag | `@ConditionalOnProperty` |
| Complex initialization | `@Bean` in `@Configuration` |
| Reduce boilerplate | `@RequiredArgsConstructor` (Lombok) |
