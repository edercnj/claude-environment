# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 02 — SOLID Principles

## SRP — Single Responsibility

Each class/module has ONE reason to change:

```
// GOOD — each class has a single responsibility
TcpServer           → manages network connections
MessageRouter       → routes by message type
DebitHandler        → processes debit transactions
DecisionEngine      → decides response code
TransactionRepo     → persists transactions
MerchantResource    → handles REST API requests

// BAD — God Class does everything
TransactionManager:
    receiveFromSocket()     → Network
    parseMessage()          → Parsing
    validateMcc()           → Business
    saveToDatabase()        → Persistence
    buildResponse()         → Serialization
```

**Rule:** If you can describe a class with "AND" (e.g., "parses messages AND saves to database"), it violates SRP.

## OCP — Open/Closed

Open for extension, closed for modification. New behavior = new class, NEVER modify existing handlers.

```
// GOOD — Strategy pattern: new type = new class, zero changes to existing
interface TransactionHandler:
    supports(messageType, processingCode): boolean
    process(request): TransactionResult

// Router uses polymorphism, NEVER switch/if-else chains
class MessageRouter:
    handlers: List<TransactionHandler>

    function route(message):
        return handlers.stream()
            .filter(h -> h.supports(message.type, message.processingCode))
            .findFirst()
            .orElseThrow(UnsupportedTransactionException)
            .process(message)
```

**Rule:** Adding a new transaction type / message handler / strategy MUST require creating a new class only — no changes to existing code.

## LSP — Liskov Substitution

Every implementation of an interface must be substitutable without breaking the caller.

```
// GOOD — all handlers are interchangeable
handlers = [DebitHandler, CreditHandler, ReversalHandler, EchoHandler]
for handler in handlers:
    if handler.supports(message):
        result = handler.process(message)  // Works for ALL handlers

// BAD — handler changes expected behavior
class SpecialHandler implements TransactionHandler:
    function process(request):
        throw NotImplementedException  // Violates LSP
```

**Rule:** If a subtype cannot fulfill the contract of its supertype, the abstraction is wrong.

## ISP — Interface Segregation

Small, focused interfaces. Clients should not depend on methods they don't use.

```
// GOOD — small, focused interfaces
interface TransactionHandler:
    process(request): TransactionResult

interface Persistable:
    save(entity): void
    findById(id): Optional<Entity>

interface HealthCheckable:
    healthCheck(): HealthStatus

// BAD — fat interface
interface Service:
    process(request): TransactionResult
    save(entity): void
    healthCheck(): HealthStatus
    sendNotification(msg): void
    generateReport(): Report
```

**Rule:** Prefer many small interfaces to one large interface. A class implementing an interface should use ALL its methods.

## DIP — Dependency Inversion

High-level modules MUST NOT depend on low-level modules. Both should depend on abstractions.

```
// GOOD — Domain defines PORT (interface)
// domain/port/outbound/PersistencePort
interface PersistencePort:
    save(transaction): void
    findByIdAndDate(id, date): Optional<Transaction>

// Adapter IMPLEMENTS the port
// adapter/outbound/persistence/DatabaseAdapter
class DatabaseAdapter implements PersistencePort:
    repository: TransactionRepository
    // ...

// Application uses the PORT, not the adapter
// application/AuthorizeTransactionUseCase
class AuthorizeTransactionUseCase:
    persistence: PersistencePort  // Interface, not DatabaseAdapter
    // ...
```

**Dependency direction:**
```
adapter.inbound → application → domain ← adapter.outbound
                                  ↑
                           (ports/interfaces)
```

**Rule:** Domain NEVER imports adapter code. Domain depends only on its own interfaces (ports) and the language standard library.

## SOLID Violations — Quick Detection

| Symptom | Likely Violation |
|---------|-----------------|
| Class with many unrelated methods | SRP |
| Modifying existing code to add new behavior | OCP |
| `instanceof` / type checks in caller code | LSP |
| Implementing interface methods with empty body / `throw NotImplemented` | ISP |
| Domain importing database/HTTP/framework code | DIP |
| Constructor with 5+ dependencies | SRP (class does too much) |
| Switch/case on type to dispatch behavior | OCP (use polymorphism) |

## Anti-Patterns (FORBIDDEN)

- God classes with multiple responsibilities
- Switch/if-else chains for dispatching behavior (use polymorphism)
- Domain depending on infrastructure (database, HTTP, framework)
- Fat interfaces forcing empty implementations
- Concrete class dependencies instead of abstractions
- Circular dependencies between modules
