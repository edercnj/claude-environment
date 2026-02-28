# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Quarkus — CDI Patterns

> Quarkus-specific CDI (Contexts and Dependency Injection) patterns.

## Constructor Injection

```java
@ApplicationScoped
public class TransactionService {
    private final TransactionRepository repository;
    private final AuthorizationEngine engine;

    @Inject
    public TransactionService(TransactionRepository repository, AuthorizationEngine engine) {
        this.repository = repository;
        this.engine = engine;
    }
}
```

**Rules:**
- Use `@ApplicationScoped` for stateless services (singleton)
- Use `@Inject` on constructor (required by CDI when multiple constructors exist)
- NEVER use field injection (`@Inject` on fields without constructor)
- No mutable state in `@ApplicationScoped` beans

## Bean Scopes

| Scope | Use | Thread Safety |
|-------|-----|---------------|
| `@ApplicationScoped` | Services, repositories, handlers | Must be stateless |
| `@RequestScoped` | REST resources (if needed) | Per-request state OK |
| `@Dependent` | Lightweight beans, created per injection point | N/A |

## Lombok

**FORBIDDEN** in Quarkus. Quarkus has its own facilities (Records, CDI).

## Anti-Patterns

- Blocking Vert.x event loop with long synchronous operations
- Mutable state in `@ApplicationScoped` beans
- Using reflection directly in native build code (use `@RegisterForReflection`)
- Heavy static initialization (static blocks with I/O) — incompatible with native
- Dynamic proxy without prior registration — incompatible with GraalVM
