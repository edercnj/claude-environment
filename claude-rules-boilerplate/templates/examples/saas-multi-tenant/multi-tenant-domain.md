# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule — Multi-Tenant SaaS Domain

## Domain Overview

TenantCloud is a multi-tenant project management SaaS where each tenant (organization) has fully isolated data, independent configuration, and usage-based billing. The system uses a shared-database, schema-per-tenant architecture: a single PostgreSQL instance contains one schema per tenant, with a shared `public` schema for cross-tenant metadata (tenant registry, billing, plans). Every request is tenant-scoped, resolved from the JWT token.

## System Role

- **Receives:** HTTP requests with tenant context embedded in JWT
- **Processes:** Tenant-scoped CRUD operations, cross-tenant admin operations, billing aggregation
- **Returns:** JSON responses scoped to the requesting tenant
- **Persists:** Tenant data in per-tenant schemas, platform data in shared public schema

## Domain Model

### Core Entities (Shared / public schema)

| Entity | Description | Key Attributes |
|--------|-------------|----------------|
| Tenant | A registered organization | id, slug, name, plan, status, schemaName, createdAt |
| Plan | A billing plan | id, name, maxSeats, maxStorageMb, maxApiCallsPerDay, pricePerMonth |
| User | A person belonging to one or more tenants | id, email, name, globalRole |
| TenantMembership | Association of user to tenant | userId, tenantId, role, invitedAt, acceptedAt |
| UsageRecord | Daily usage tracking per tenant | tenantId, date, apiCalls, storageUsedMb, activeSeats |

### Core Entities (Per-tenant schema)

| Entity | Description | Key Attributes |
|--------|-------------|----------------|
| Project | A project within the tenant | id, name, description, status, ownerId |
| Task | A work item within a project | id, projectId, title, assigneeId, status, priority, dueDate |
| Comment | A comment on a task | id, taskId, authorId, body, createdAt |

## Business Rules

### RULE-001: Tenant Data Isolation

- Each tenant has a dedicated PostgreSQL schema named `tenant_{slug}`
- ALL queries within a request MUST use the tenant's schema as `search_path`
- The tenant is resolved from the JWT `tenant_id` claim on every request
- NEVER allow a query to access another tenant's schema
- Cross-tenant queries (admin dashboard, billing) ONLY access the `public` schema

### RULE-002: Schema Lifecycle

- On tenant creation: create schema `tenant_{slug}`, run Alembic migrations
- On tenant deletion: mark as INACTIVE (soft delete), do NOT drop schema immediately
- Schema cleanup: scheduled job drops schemas for tenants inactive > 90 days
- Migration: new Alembic migrations are applied to ALL active tenant schemas on deploy

### RULE-003: Tenant-Aware Connection Pooling

- Before executing any query, set `search_path = tenant_{slug}, public`
- Connection is returned to pool with `search_path` reset to `public`
- NEVER cache a connection with a tenant-specific `search_path`
- Use middleware to set/reset `search_path` around each request

### RULE-004: Rate Limiting per Tenant

- Each tenant has API call limits based on their plan
- Rate limiting uses Redis with key `rate:{tenant_id}:{date}`
- When limit is exceeded, return HTTP 429 with `Retry-After` header
- Usage is recorded in `UsageRecord` for billing
- Admin/platform endpoints are NOT rate-limited per tenant

### RULE-005: Seat Management

- Each plan has a `maxSeats` limit
- A "seat" is an active `TenantMembership` with `acceptedAt != null`
- Inviting a user when seats are full returns HTTP 402 (Payment Required)
- Removing a user frees a seat immediately
- Seat count is cached in Redis, invalidated on membership changes

### RULE-006: Usage-Based Billing

- Daily: increment `apiCalls` in `UsageRecord` for each API request
- Daily: calculate `storageUsedMb` from tenant schema disk usage
- Monthly: aggregate `UsageRecord` entries for invoice generation
- Overage charges: if usage exceeds plan limits, charge per-unit overage

## Domain States and Transitions

```
Tenant States:
PROVISIONING -> ACTIVE -> SUSPENDED -> INACTIVE
                       -> INACTIVE (admin-initiated deactivation)
SUSPENDED: triggered by payment failure, all API calls return 402
INACTIVE: soft-deleted, data preserved for 90 days
```

```
TenantMembership States:
INVITED -> ACCEPTED -> REMOVED
        -> EXPIRED (invitation not accepted within 7 days)
```

## Sensitive Data

| Data | Classification | Can Log? | Can Persist? | Can Return in API? |
|------|---------------|----------|--------------|-------------------|
| Tenant Data (projects, tasks) | Tenant-Scoped | Tenant ID only | Yes (tenant schema) | Yes (to tenant members) |
| User Email | PII | Masked | Yes | Yes (to self and admins) |
| User Password | SECRET | NEVER | Hashed (argon2) | NEVER |
| JWT Token | SECRET | NEVER | Redis (sessions) | In auth header only |
| API Key | SECRET | Last 4 chars | Hashed | Last 4 chars only |
| Billing Info | RESTRICTED | NEVER | Via Stripe | Last 4 card digits |
| Tenant Slug | Internal | Yes | Yes | Yes |

### Data Handling Rules
- Tenant data NEVER appears in logs (only tenant_id as correlation)
- Cross-tenant data access is a CRITICAL security incident
- Deleted tenant data is retained for 90 days, then permanently purged
- All database queries MUST include tenant context -- no unscoped queries

## Domain-Specific Test Scenarios

### Unit Test Scenarios

| Scenario | Input | Expected Output | Rule |
|----------|-------|-----------------|------|
| Schema path resolution | tenant_id from JWT | search_path = tenant_{slug} | RULE-001 |
| Rate limit within bounds | 99/100 calls used | Request succeeds | RULE-004 |
| Rate limit exceeded | 100/100 calls used | HTTP 429 | RULE-004 |
| Seat limit enforcement | maxSeats=5, active=5 | Invite returns 402 | RULE-005 |
| Seat freed on removal | remove member | seat count decremented | RULE-005 |

### Integration Test Scenarios

| Scenario | Flow | Validates |
|----------|------|-----------|
| Tenant provisioning | Create tenant -> Schema exists -> Migrations applied | RULE-002 |
| Cross-tenant isolation | Tenant A creates data -> Tenant B queries -> empty | RULE-001 |
| Concurrent tenant requests | 10 tenants, parallel requests -> correct data per tenant | RULE-001, RULE-003 |
| Schema migration rollout | Deploy with new migration -> All tenant schemas updated | RULE-002 |
| Billing cycle | 30 days of usage -> Invoice generated with correct totals | RULE-006 |

## Domain Anti-Patterns

- Querying the database without setting `search_path` (data leakage risk)
- Caching query results without tenant key in cache key (cross-tenant leakage)
- Using a global connection pool without resetting `search_path` after each request
- Dropping tenant schema on deletion (must soft-delete and retain for 90 days)
- Rate limiting globally instead of per-tenant (one noisy tenant impacts all)
- Hardcoding plan limits instead of reading from Plan entity
- Allowing tenant admin to access platform-level endpoints
- Running migrations on only some tenant schemas (schema drift)
- Logging tenant data contents (only log tenant_id for correlation)

## Glossary

| Term | Definition |
|------|-----------|
| Tenant | An organization/company using the platform; maps to one PostgreSQL schema |
| Seat | An active user membership within a tenant; counted for billing |
| Schema-per-tenant | Architecture where each tenant's data lives in a separate PostgreSQL schema |
| search_path | PostgreSQL session variable that determines which schema is used for unqualified table names |
| Noisy Neighbor | A tenant whose heavy usage degrades performance for other tenants |
| Overage | Usage exceeding the plan's included limits; billed at per-unit rates |
| Slug | URL-safe, lowercase identifier for a tenant (e.g., `acme-corp`) |
