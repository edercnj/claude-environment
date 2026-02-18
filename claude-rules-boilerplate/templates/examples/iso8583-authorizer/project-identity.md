# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 01 — Project Identity and Constraints

## Identity
- **Name:** authorizer-simulator
- **Type:** Server application (not a library)
- **Purpose:** ISO 8583 financial transaction authorizer simulator (1987, 1993, 2021)
- **Framework:** Java 21 + Quarkus
- **Database:** PostgreSQL (containerized on Kubernetes)
- **Protocol:** TCP Socket (ISO 8583) + REST API (management)
- **Deployment:** Kubernetes (cloud-agnostic)
- **ISO Dependency:** com.bifrost:b8583 (ISO 8583 parsing/packing library)

## Source of Truth (Hierarchy)
1. EPIC-001 (vision and global rules)
2. ADRs (architectural decisions)
3. STORY-NNN (detailed requirements)
4. Rules (.claude/rules/)
5. Source code

## Language
- Java code: **English** (classes, methods, variables, Javadoc)
- Commits: **English** (Conventional Commits)
- Stories and business documentation: **Portuguese**
- ADRs: **Portuguese**
- Application logs: **English**

## Maven Coordinates
```xml
<groupId>com.bifrost</groupId>
<artifactId>authorizer-simulator</artifactId>
<version>0.1.0-SNAPSHOT</version>
<packaging>jar</packaging>
```

## Technology Stack
| Layer | Technology |
|-------|-----------|
| Framework | Quarkus 3.x (latest stable) |
| Language | Java 21 (LTS) |
| Build | Maven 3.9+ |
| Database | PostgreSQL 16+ |
| ORM | Hibernate ORM with Panache |
| DB Migration | Flyway |
| TCP Socket | Vert.x / Netty (via Quarkus) |
| REST API | RESTEasy Reactive (JAX-RS) |
| JSON | Jackson |
| Health/Metrics | OpenTelemetry (Traces, Metrics, Logs) + SmallRye Health |
| Native Build | Quarkus Native (GraalVM / Mandrel) |
| Container | Docker / Podman |
| Orchestration | Kubernetes (any distribution) |
| Testing | JUnit 5 + AssertJ + Testcontainers + REST Assured |
| ISO 8583 | com.bifrost:b8583 |

## Constraints
- **Cloud-Agnostic:** ZERO dependencies on cloud-specific services (AWS, GCP, Azure)
- **PostgreSQL on K8S:** Database runs as StatefulSet on Kubernetes, not as managed service
- **No vendor lock-in:** Use only standard APIs (JPA, JAX-RS, CDI) when possible
- **Horizontal scalability:** Application must be stateless to allow multiple replicas
- **Externalized configuration:** All configuration via environment variables or ConfigMaps
- **Quarkus Native:** Native build mandatory for production (startup < 100ms, RSS < 128MB)
- **Multi-Version ISO:** Mandatory support for 3 ISO 8583 versions (1987, 1993, 2021) via b8583 library
- **OpenTelemetry:** Observability via OpenTelemetry (OTLP), with no vendor lock-in on monitoring backends
