# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 01 — Project Identity and Constraints

## Identity
- **Name:** shopwave-api
- **Type:** REST API server
- **Purpose:** E-commerce backend API for product catalog, shopping cart, order processing, and payment integration
- **Framework:** Node.js 20 + Express.js
- **Language:** TypeScript 5.x
- **Database:** PostgreSQL 16 (primary) + Redis 7 (cache/sessions)
- **Deployment:** Kubernetes (cloud-agnostic)

## Source of Truth (Hierarchy)
1. Product Requirements Document (PRD)
2. Architecture Decision Records (ADRs)
3. User Stories (Jira)
4. Rules (.claude/rules/)
5. Source code

## Language
- Source code: **English** (classes, functions, variables, JSDoc)
- Commits: **English** (Conventional Commits)
- Technical documentation: **English**
- Business documentation: **English**
- Application logs: **English**

## npm Coordinates
```json
{
  "name": "@shopwave/api",
  "version": "0.1.0",
  "engines": { "node": ">=20.0.0" }
}
```

## Technology Stack
| Layer | Technology |
|-------|-----------|
| Runtime | Node.js 20 LTS |
| Language | TypeScript 5.x |
| Framework | Express.js 4.x |
| Build | esbuild + tsx |
| Database | PostgreSQL 16+ |
| ORM | Prisma 5.x |
| Cache | Redis 7 (ioredis) |
| DB Migration | Prisma Migrate |
| REST API | Express Router |
| Validation | Zod |
| Authentication | JWT (jose) |
| Payment Gateway | Stripe SDK |
| Search | PostgreSQL full-text search (pg_trgm) |
| File Storage | S3-compatible (MinIO on K8S) |
| Health/Metrics | Prometheus (prom-client) |
| Container | Docker |
| Orchestration | Kubernetes (any distribution) |
| Testing | Vitest + Supertest + Testcontainers |

## Constraints
- **Cloud-Agnostic:** ZERO dependencies on cloud-specific services
- **Stateless:** Application is stateless; sessions in Redis
- **Externalized configuration:** All config via environment variables
- **No vendor lock-in:** S3-compatible API for storage (not AWS-specific)
- **Performance:** p99 < 200ms for catalog reads, p99 < 500ms for order placement
- **PCI Compliance:** NEVER store raw card data; delegate to Stripe
- **Horizontal scalability:** Multiple replicas behind load balancer
- **Idempotency:** All write operations support idempotency keys
