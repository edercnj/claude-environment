# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# OpenAPI 3.1 Specification Conventions

## Specification Version

All API specifications MUST use OpenAPI 3.1.x (aligned with JSON Schema 2020-12). Do NOT use OpenAPI 2.0 (Swagger) or 3.0.x for new projects.

## File Organization

### Single-File Approach (Small APIs)

Use a single `openapi.yaml` when the API has fewer than 10 endpoints and fewer than 15 schemas. Place at `docs/openapi.yaml` or `src/main/resources/openapi.yaml` depending on framework convention.

### Multi-File Approach (Recommended for Larger APIs)

| Path | Contents |
|------|----------|
| `openapi/openapi.yaml` | Root document: info, servers, security, tags, path references |
| `openapi/paths/` | One file per resource (e.g., `orders.yaml`, `customers.yaml`) |
| `openapi/components/schemas/` | One file per schema (e.g., `Order.yaml`, `Customer.yaml`) |
| `openapi/components/parameters/` | Reusable parameters (pagination, filters) |
| `openapi/components/responses/` | Reusable responses (errors, pagination wrappers) |
| `openapi/components/security-schemes/` | Authentication definitions |

Use `$ref` to link files. Relative paths MUST be used for internal references. All `$ref` paths MUST resolve without external network calls.

## Schema Reuse with $ref

- Every schema used in more than one endpoint MUST be defined in `components/schemas` and referenced via `$ref`
- NEVER inline complex schemas in path definitions; always extract to components
- Compose schemas with `allOf` for inheritance, `oneOf` for polymorphism, `anyOf` for flexible unions
- Use `$ref` for shared parameters (pagination, sorting, common filters) in `components/parameters`
- Use `$ref` for shared response structures (error responses, paginated wrappers) in `components/responses`

## Example Values

**Every schema and every field MUST have an `example` value.** This is mandatory, not optional.

| Element | Requirement |
|---------|-------------|
| Schema-level | `example` object showing a complete, realistic instance |
| String fields | Realistic value (not "string" or "test") |
| Numeric fields | Realistic value within documented constraints |
| Date/time fields | ISO 8601 with timezone (e.g., `2026-02-19T14:30:00Z`) |
| Enum fields | One of the valid enum values |
| Array fields | Array with 1-2 realistic items |
| Nested objects | Fully populated example |

Use `examples` (plural) for multiple named scenarios on request/response bodies to document edge cases and variants.

## Security Schemes

### Supported Schemes

| Scheme | Type | When to Use |
|--------|------|-------------|
| API Key (header) | `apiKey` in `header` | Machine-to-machine, internal services |
| API Key (query) | `apiKey` in `query` | ONLY when header is impossible (webhooks) |
| Bearer Token (JWT) | `http` with `scheme: bearer` | User-facing APIs, OAuth2 resource servers |
| OAuth2 | `oauth2` with flows | Public APIs with delegated authorization |

### Documentation Requirements

- Every security scheme MUST include a `description` explaining how to obtain credentials
- Scopes MUST be documented with human-readable descriptions
- Apply security globally in the root `security` field; override per-operation only when an endpoint has different requirements
- Public endpoints (health checks, docs) MUST explicitly declare `security: []` to indicate no auth

## Operation IDs

Operation IDs MUST follow `camelCase` with the pattern: `verb` + `Resource` (+ optional qualifier).

| Pattern | Example | Notes |
|---------|---------|-------|
| List collection | `listOrders` | Always "list" for collection GET |
| Get single | `getOrder` | Always "get" for single resource GET |
| Create | `createOrder` | Always "create" for POST |
| Full update | `updateOrder` | Always "update" for PUT |
| Partial update | `patchOrder` | Always "patch" for PATCH |
| Delete | `deleteOrder` | Always "delete" for DELETE |
| Sub-resource | `listOrderLineItems` | Parent + child resource |
| Action | `cancelOrder` | Domain verb for non-CRUD actions |

**Constraints:**
- Operation IDs MUST be unique across the entire specification
- Operation IDs MUST NOT contain underscores, hyphens, or dots
- Operation IDs are used for SDK client method generation; choose names that produce clean SDKs

## Tags for Grouping

- Every operation MUST have exactly one tag
- Tags MUST match resource names in PascalCase plural (e.g., `Orders`, `Customers`, `PaymentMethods`)
- Define tags at the root level with `name`, `description`, and optional `externalDocs`
- Order tags in the root definition to control documentation rendering order
- NEVER use more than one tag per operation (it duplicates entries in generated docs)

## Request/Response Documentation Requirements

### Request Documentation

| Element | Required | Notes |
|---------|:--------:|-------|
| `summary` on operation | Yes | Short one-line description (under 80 chars) |
| `description` on operation | Yes (if complex) | Explain business rules, side effects, preconditions |
| `description` on every parameter | Yes | Explain purpose, constraints, default value |
| `required` flag on parameters | Yes | Explicit true/false, never rely on defaults |
| `description` on request body | Yes | Explain expected payload |
| `example` on request body | Yes | Realistic, complete example |

### Response Documentation

| Element | Required | Notes |
|---------|:--------:|-------|
| All possible status codes | Yes | Document every status code the endpoint can return |
| `description` on each response | Yes | Explain when this status is returned |
| `example` on each response body | Yes | Realistic example per status code |
| Error responses | Yes | Reference shared `ProblemDetail` schema via `$ref` |
| `headers` on responses | When applicable | Rate limit headers, Location header, etc. |

## Discriminator for Polymorphic Types

Use `discriminator` with `oneOf` when a field can be one of several typed objects.

**Rules:**
- The discriminator property MUST be a required string field on every sub-schema
- Define explicit `mapping` between discriminator values and schema references
- Discriminator field name: use `type` or `kind` consistently across the API
- Each variant schema MUST include the discriminator property in its own `required` and `properties`
- Document the available discriminator values in the parent schema description

**When to use discriminator:**
- Payment methods (card, bank transfer, wallet)
- Notification channels (email, SMS, push)
- Event payloads with different structures per event type

**When NOT to use discriminator:**
- Simple optional fields (use nullable fields instead)
- Two variants that differ by only one field (use optional fields)

## Additional Conventions

### Servers

- Define at least `development`, `staging`, and `production` server URLs
- Use server variables for configurable parts (e.g., region, version)

### Schema Conventions

| Rule | Convention |
|------|-----------|
| Field names | camelCase |
| Required fields | Explicitly listed in `required` array; NEVER rely on defaults |
| Nullable fields | Use `type: ["string", "null"]` (OpenAPI 3.1 JSON Schema syntax) |
| Date fields | `format: date-time` with ISO 8601 |
| Money fields | Integer cents (`type: integer`) or `type: string` with documented precision |
| Enums | Uppercase strings (`APPROVED`, `PENDING`, `REJECTED`) |
| UUIDs | `format: uuid` |
| Emails | `format: email` |
| URIs | `format: uri` |

### Specification Validation

- Run `spectral lint` or equivalent on every CI build
- Specification MUST be valid against the OpenAPI 3.1 JSON Schema
- Breaking change detection MUST be part of the CI pipeline (use `oasdiff` or equivalent)

## Anti-Patterns (FORBIDDEN)

- Inline schemas in path definitions for types used more than once -- always extract to `components/schemas`
- Missing `example` values on schemas or fields -- every schema MUST have examples
- Generic operation IDs (`operation1`, `endpoint2`) -- use the `verbResource` convention
- Multiple tags per operation -- use exactly one tag
- Undocumented status codes -- every possible response MUST be declared
- Using `additionalProperties: true` without explicit documentation -- it hides the actual contract
- Defining security schemes but not applying them globally or per-operation
- Using `default` response as a catch-all instead of documenting specific error codes
- Referencing external URLs in `$ref` that require network access to resolve
- Missing `description` on parameters, schemas, or operations
- Using OpenAPI 2.0 / Swagger syntax in 3.1 specifications
- Specification files that do not pass linting in CI
