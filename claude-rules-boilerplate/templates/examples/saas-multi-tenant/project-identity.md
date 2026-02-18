# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 01 — Project Identity and Constraints

## Identity
- **Name:** tenantcloud-api
- **Type:** Multi-tenant SaaS API
- **Purpose:** Backend API for a multi-tenant project management SaaS with per-tenant data isolation, billing, and usage tracking
- **Framework:** Python 3.12 + FastAPI
- **Language:** Python 3.12
- **Database:** PostgreSQL 16 (shared database, schema-per-tenant) + Redis 7 (cache/rate-limiting)
- **Deployment:** Kubernetes (cloud-agnostic)

## Source of Truth (Hierarchy)
1. Product Requirements Document (PRD)
2. Architecture Decision Records (ADRs)
3. User Stories (Linear)
4. Rules (.claude/rules/)
5. Source code

## Language
- Source code: **English** (classes, functions, variables, docstrings)
- Commits: **English** (Conventional Commits)
- Technical documentation: **English**
- Business documentation: **English**
- Application logs: **English**

## Build Coordinates
```toml
[project]
name = "tenantcloud-api"
version = "0.1.0"
requires-python = ">=3.12"
```

## Technology Stack
| Layer | Technology |
|-------|-----------|
| Runtime | Python 3.12 |
| Framework | FastAPI 0.110+ |
| ASGI Server | Uvicorn |
| Database | PostgreSQL 16+ |
| ORM | SQLAlchemy 2.x (async) |
| DB Migration | Alembic |
| Cache | Redis 7 (redis-py async) |
| Authentication | JWT (python-jose) + OAuth2 |
| Background Tasks | Celery + Redis broker |
| Validation | Pydantic v2 |
| Health/Metrics | Prometheus (prometheus-fastapi-instrumentator) |
| Container | Docker |
| Orchestration | Kubernetes (any distribution) |
| Testing | pytest + httpx + testcontainers-python |

## Constraints
- **Cloud-Agnostic:** ZERO dependencies on cloud-specific services
- **Tenant Isolation:** Data MUST be isolated per tenant at the database level (schema-per-tenant)
- **Stateless:** Application is stateless; tenant context resolved from JWT on every request
- **Externalized configuration:** All config via environment variables
- **Performance:** p99 < 150ms for tenant-scoped queries
- **Zero Cross-Tenant Leakage:** A bug MUST NOT expose one tenant's data to another
- **Horizontal scalability:** Multiple replicas, tenant-aware connection pooling
- **Usage-Based Billing:** Track API calls, storage, and seats per tenant for billing
