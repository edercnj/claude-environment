# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 05 — Architecture Principles (Hexagonal / Ports & Adapters)

## Overview

The application follows **Hexagonal Architecture** (Ports & Adapters), clearly separating business domain from infrastructure.

```
┌─────────────────────────────────────────────────────┐
│                    ADAPTERS (Inbound)                │
│  ┌──────────────┐  ┌──────────────────────────────┐ │
│  │ Protocol A    │  │ Protocol B                   │ │
│  │ (e.g. TCP)   │  │ (e.g. REST API)              │ │
│  └──────┬───────┘  └──────────┬───────────────────┘ │
│         │                     │                      │
│  ═══════╪═════════════════════╪══════════════════    │
│         │     PORTS (Inbound)  │                     │
│  ┌──────▼───────┐  ┌─────────▼──────────────────┐  │
│  │ MessagePort  │  │ ManagementPort              │  │
│  └──────┬───────┘  └─────────┬──────────────────┘  │
│         │                     │                      │
│  ┌──────▼─────────────────────▼──────────────────┐  │
│  │              DOMAIN (Core)                     │  │
│  │  ┌─────────────────┐  ┌───────────────────┐   │  │
│  │  │ Business Logic   │  │ Domain Models     │   │  │
│  │  └─────────────────┘  └───────────────────┘   │  │
│  │  ┌─────────────────┐  ┌───────────────────┐   │  │
│  │  │ Decision Rules   │  │ Routing           │   │  │
│  │  └─────────────────┘  └───────────────────┘   │  │
│  └──────┬─────────────────────┬──────────────────┘  │
│         │     PORTS (Outbound) │                     │
│  ┌──────▼───────┐  ┌─────────▼──────────────────┐  │
│  │ Persistence  │  │ LogPort / EventPort         │  │
│  │ Port         │  │                              │  │
│  └──────┬───────┘  └─────────┬──────────────────┘  │
│         │                     │                      │
│  ═══════╪═════════════════════╪══════════════════    │
│         │    ADAPTERS (Outbound)│                    │
│  ┌──────▼───────┐  ┌─────────▼──────────────────┐  │
│  │ Database     │  │ Logger / Event Bus          │  │
│  └──────────────┘  └───────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

## Package / Module Structure

```
{root_package}/
├── domain/                    # CORE — Zero external dependencies
│   ├── model/                 # Domain entities, value objects, records
│   ├── engine/                # Business logic, decision engines
│   ├── rule/                  # Business rules
│   └── port/                  # Interfaces (Ports)
│       ├── inbound/           # Inbound ports
│       └── outbound/          # Outbound ports
│
├── adapter/                   # ADAPTERS — Infrastructure implementations
│   ├── inbound/
│   │   ├── {protocol_a}/     # Protocol A adapter (TCP, gRPC, etc.)
│   │   └── {protocol_b}/     # Protocol B adapter (REST, GraphQL, etc.)
│   │       ├── resource/     # Controllers / Handlers
│   │       ├── dto/          # Request/Response DTOs
│   │       └── mapper/       # DTO <-> Domain mappers
│   └── outbound/
│       ├── persistence/      # Database adapter
│       │   ├── entity/       # ORM Entities
│       │   ├── repository/   # Repositories
│       │   └── mapper/       # Entity <-> Domain mappers
│       └── {external}/       # Other external adapters
│
├── application/               # APPLICATION — Orchestration (Use Cases)
│   ├── {UseCase}UseCase
│   └── ...
│
└── config/                    # CONFIG — Framework configuration
```

## Dependency Rules (STRICT)

```
adapter.inbound → application → domain ← adapter.outbound
                                  ↑
                           (ports/interfaces)
```

### Golden Rule

- **domain/** MUST NOT import ANYTHING from `adapter/`, framework-specific packages, or infrastructure libraries
- **domain/** uses only the language standard library + domain-specific libraries
- **application/** orchestrates domain and ports, DOES NOT know adapter implementations
- **adapter/** implements ports and converts between external formats and domain

### Permitted Dependencies

| Package | Can depend on |
|---------|---------------|
| domain.model | Standard library, domain libraries |
| domain.engine | domain.model, domain.rule, domain.port |
| domain.port | domain.model |
| application | domain.* |
| adapter.inbound.* | application, domain.port, framework libraries |
| adapter.outbound.* | domain.port, domain.model, infrastructure libraries |
| config | Framework configuration |

## Thread-Safety Classifications

| Classification | Examples | Rule |
|---------------|---------|-------|
| Stateless (Singleton) | Services, Repositories, Handlers | No mutable state |
| Request-Scoped | REST Resources, Request Handlers | Scoped to request lifecycle |
| Immutable | Records, DTOs, Value Objects | Thread-safe by design |
| Managed | ORM Entities | Only within transaction, never share across threads |

## Mapper Pattern

Mappers convert between architecture layers. Two types:

### DTO Mappers (Inbound Adapter)
- Location: `adapter.inbound.{protocol}.mapper`
- Convert between DTOs (request/response) and domain models
- Masking / formatting of data for external exposure happens here

### Entity Mappers (Outbound Adapter)
- Location: `adapter.outbound.persistence.mapper`
- Convert between domain models and ORM entities
- NEVER expose ORM entities outside the persistence adapter

### Mapper Rules

| Rule | Detail |
|------|--------|
| Structure | Utility class: static methods, private constructor |
| DI | NOT a managed bean (no dependency injection) |
| Masking | Masking logic lives in the mapper that **exposes** data externally |
| Null safety | Check nulls on optional fields before mapping |
| Auto-mapping | Code-generation mapping tools (MapStruct, AutoMapper) must be validated for native build compatibility |

> **Exception:** Mappers needing injected dependencies (e.g., JSON serializer) MAY be managed beans with constructor injection.

## Persistence Rules

- ORM entities live in `adapter.outbound.persistence.entity`
- Domain models live in `domain.model` — are immutable records or value objects
- Mappers convert Entity <-> Domain
- NEVER expose ORM entities outside the persistence adapter

## Architecture Variants

This rule describes **Hexagonal Architecture**. The principles apply equally to:
- **Clean Architecture** (Uncle Bob): same dependency rule, different naming (Entities, Use Cases, Interface Adapters, Frameworks)
- **Onion Architecture**: concentric layers with same inward dependency direction
- **Ports & Adapters**: synonym for Hexagonal

The key invariant across all variants: **dependencies point inward toward the domain**.

> **Detailed Reference:** See `patterns/architectural/hexagonal-architecture.md` for expanded coverage including advanced port design, adapter composition, and testing strategies. Additional architectural patterns (CQRS, Event Sourcing, Modular Monolith) are in the `patterns/architectural/` directory.

## Anti-Patterns (FORBIDDEN)

- Domain importing framework or infrastructure code
- ORM entities exposed in API responses
- Business logic in adapters (controllers, repositories)
- Direct database access from domain layer
- Circular dependencies between layers
- Application layer knowing concrete adapter implementations
- Shared mutable state in singleton services
