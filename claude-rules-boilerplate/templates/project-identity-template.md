# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 01 — Project Identity and Constraints

<!-- TEMPLATE INSTRUCTIONS:
     Replace all {PLACEHOLDER} values with your project-specific information.
     Remove this comment block after filling in all values. -->

## Identity
- **Name:** {PROJECT_NAME}
- **Type:** {PROJECT_TYPE} <!-- api | cli | library | worker | fullstack -->
- **Purpose:** {PROJECT_PURPOSE}
- **Framework:** {FRAMEWORK}
- **Language:** {LANGUAGE}
- **Database:** {DATABASE} <!-- e.g., PostgreSQL, MongoDB, DynamoDB, none -->
- **Deployment:** {DEPLOYMENT} <!-- e.g., Kubernetes, AWS Lambda, Docker Compose, bare metal -->

## Source of Truth (Hierarchy)

<!-- Define the precedence order for conflicting information.
     The higher the item, the more authority it has. -->

{SOURCE_OF_TRUTH}

<!-- Example:
1. Product Requirements Document (PRD)
2. Architecture Decision Records (ADRs)
3. User Stories / Tickets
4. Rules (.claude/rules/)
5. Source code
-->

## Language

<!-- Define which human language is used in each context.
     This prevents mixing languages in code, commits, and docs. -->

- Source code (classes, methods, variables): **{CODE_LANGUAGE}**
- Commits: **{COMMIT_LANGUAGE}** ({COMMIT_FORMAT})
- Technical documentation: **{TECH_DOCS_LANGUAGE}**
- Business documentation: **{BUSINESS_DOCS_LANGUAGE}**
- Application logs: **{LOGS_LANGUAGE}**

## Build Coordinates

{BUILD_COORDINATES}

<!-- Examples:

Maven:
```xml
<groupId>com.example</groupId>
<artifactId>{PROJECT_NAME}</artifactId>
<version>0.1.0-SNAPSHOT</version>
<packaging>jar</packaging>
```

npm:
```json
{
  "name": "@scope/{PROJECT_NAME}",
  "version": "0.1.0"
}
```

Cargo:
```toml
[package]
name = "{PROJECT_NAME}"
version = "0.1.0"
edition = "2021"
```
-->

## Technology Stack

{TECH_STACK_TABLE}

<!-- Example:
| Layer | Technology |
|-------|-----------|
| Framework | Express.js 4.x |
| Language | TypeScript 5.x |
| Build | npm / esbuild |
| Database | PostgreSQL 16+ |
| ORM | Prisma |
| REST API | Express Router |
| JSON | native |
| Health/Metrics | Prometheus + prom-client |
| Container | Docker |
| Orchestration | Kubernetes |
| Testing | Jest + Supertest + Testcontainers |
-->

## Constraints

{CONSTRAINTS_LIST}

<!-- List all hard constraints that MUST be respected.
     These are non-negotiable architectural boundaries.

     Example:
- **Cloud-Agnostic:** ZERO dependencies on cloud-specific services (AWS, GCP, Azure)
- **Stateless:** Application must be stateless to allow horizontal scaling
- **Externalized configuration:** All configuration via environment variables
- **No vendor lock-in:** Use only standard APIs when possible
- **Performance:** p99 latency < 200ms for all endpoints
- **Security:** All inputs validated, no credentials in code
-->
