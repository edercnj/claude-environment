# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 05 — Hexagonal Architecture (Ports & Adapters)

## Overview
The authorizer-simulator follows **Hexagonal Architecture** (Ports & Adapters), clearly separating business domain from infrastructure.

```
┌─────────────────────────────────────────────────────┐
│                    ADAPTERS (Inbound)                │
│  ┌──────────────┐  ┌──────────────────────────────┐ │
│  │ TCP Socket   │  │ REST API (JAX-RS)            │ │
│  │ (ISO 8583)   │  │ /api/v1/merchants            │ │
│  └──────┬───────┘  └──────────┬───────────────────┘ │
│         │                     │                      │
│  ═══════╪═════════════════════╪══════════════════    │
│         │     PORTS (Inbound)  │                     │
│  ┌──────▼───────┐  ┌─────────▼──────────────────┐  │
│  │ MessagePort  │  │ MerchantManagementPort      │  │
│  └──────┬───────┘  └─────────┬──────────────────┘  │
│         │                     │                      │
│  ┌──────▼─────────────────────▼──────────────────┐  │
│  │              DOMAIN (Core)                     │  │
│  │  ┌─────────────────┐  ┌───────────────────┐   │  │
│  │  │ Authorization    │  │ Transaction       │   │  │
│  │  │ Engine           │  │ Domain Model      │   │  │
│  │  └─────────────────┘  └───────────────────┘   │  │
│  │  ┌─────────────────┐  ┌───────────────────┐   │  │
│  │  │ Message Router   │  │ Decision Rules    │   │  │
│  │  └─────────────────┘  └───────────────────┘   │  │
│  └──────┬─────────────────────┬──────────────────┘  │
│         │     PORTS (Outbound) │                     │
│  ┌──────▼───────┐  ┌─────────▼──────────────────┐  │
│  │ Persistence  │  │ TransactionLogPort          │  │
│  │ Port         │  │                              │  │
│  └──────┬───────┘  └─────────┬──────────────────┘  │
│         │                     │                      │
│  ═══════╪═════════════════════╪══════════════════    │
│         │    ADAPTERS (Outbound)│                    │
│  ┌──────▼───────┐  ┌─────────▼──────────────────┐  │
│  │ PostgreSQL   │  │ Transaction Logger          │  │
│  │ (Panache)    │  │ (SLF4J + DB)               │  │
│  └──────────────┘  └───────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

## Package Structure
```
com.bifrost.simulator/
├── domain/                    # 🔴 CORE — Zero external dependencies
│   ├── model/                 # Domain entities (Transaction, Merchant, Terminal)
│   ├── engine/                # Authorization engine and decision rules
│   ├── rule/                  # Business rules (CentsRule, TimeoutRule)
│   └── port/                  # Interfaces (Ports)
│       ├── inbound/           # Inbound ports (MessagePort, MerchantPort)
│       └── outbound/          # Outbound ports (PersistencePort, LogPort)
│
├── adapter/                   # 🔵 ADAPTERS — Infrastructure implementations
│   ├── inbound/
│   │   ├── socket/            # TCP Socket adapter (Vert.x/Netty)
│   │   │   ├── TcpServer.java
│   │   │   ├── MessageFrameDecoder.java
│   │   │   └── IsoMessageHandler.java
│   │   └── rest/              # REST API adapter (JAX-RS)
│   │       ├── MerchantResource.java
│   │       └── TerminalResource.java
│   └── outbound/
│       ├── persistence/       # PostgreSQL adapter (Panache)
│       │   ├── entity/        # JPA Entities
│       │   ├── repository/    # Panache Repositories
│       │   └── mapper/        # Entity ↔ Domain mappers
│       └── logging/           # Logging adapter
│
├── application/               # 🟢 APPLICATION — Orchestration (Use Cases)
│   ├── AuthorizeTransactionUseCase.java
│   ├── ProcessReversalUseCase.java
│   ├── ManageMerchantUseCase.java
│   └── EchoTestUseCase.java
│
└── config/                    # ⚙️ CONFIG — Quarkus configuration
    ├── SimulatorConfig.java
    └── ApplicationLifecycle.java
```

## Dependency Rules (STRICT)
```
adapter.inbound → application → domain ← adapter.outbound
                                  ↑
                           (ports/interfaces)
```

### Rule of Gold
- **domain/** MUST NOT import ANYTHING from `adapter/`, `jakarta.*`, `io.quarkus.*`
- **domain/** uses only JDK 21 + b8583 library
- **application/** orchestrates domain and ports, DOES NOT know adapter implementations
- **adapter/** implements ports and converts between external formats and domain

### Permitted Dependencies
| Package | Can depend on |
|---------|-----------------|
| domain.model | JDK 21, b8583 |
| domain.engine | domain.model, domain.rule, domain.port |
| domain.port | domain.model |
| application | domain.* |
| adapter.inbound.socket | application, domain.port, Vert.x/Netty, b8583 |
| adapter.inbound.rest | application, domain.port, JAX-RS, Jackson |
| adapter.outbound.persistence | domain.port, domain.model, JPA, Panache |
| config | Quarkus Config, CDI |

## Thread-Safety
| Classification | Classes | Rule |
|--------------|---------|-------|
| Stateless (CDI Singleton) | Services, Repositories, Handlers | `@ApplicationScoped`, no mutable state |
| Request-Scoped | REST Resources | `@RequestScoped` if needed |
| Immutable | Records (DTOs, VOs) | Thread-safe by design |
| Managed | JPA Entities | Only within transaction, never share between threads |

## Persistence
- **JPA Entities** live in `adapter.outbound.persistence.entity`
- **Domain Models** live in `domain.model` — are Records or immutable classes
- **Mappers** convert Entity ↔ Domain — live in `adapter.outbound.persistence.mapper`
- NEVER expose JPA Entities outside persistence adapter

## Resilience
- Resilience patterns at application level (circuit breaker, rate limiting, bulkhead, retry, timeout, fallback, backpressure, graceful degradation) are defined in **Rule 24 — Application Resilience**
- Resilience is responsibility of **application layer** and **adapters**, NOT the domain
- MicroProfile Fault Tolerance (`@CircuitBreaker`, `@Retry`, etc.) is applied to outbound adapters and use cases
- Rate limiting (Bucket4j) is applied to inbound adapters (REST filter, TCP handler)
