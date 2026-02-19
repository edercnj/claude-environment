# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# GraphQL Schema Design Conventions

## Schema Design Approach

**Schema-first (SDL-first) is the recommended approach.** Define the schema in `.graphql` files before writing resolvers.

| Approach | When to Use | Tradeoffs |
|----------|-------------|-----------|
| Schema-first (SDL) | Default choice for all projects | Clear contract, easy review, language-agnostic |
| Code-first | When schema must be derived from existing types | Tight coupling with implementation language |

**Rules for schema-first:**
- Schema files live in a dedicated directory (e.g., `schema/` or `graphql/`)
- Split schema by domain: `schema/orders.graphql`, `schema/customers.graphql`
- Use `extend type Query` and `extend type Mutation` in each domain file
- Single entry point (`schema.graphql`) that stitches domain files together
- Schema changes MUST be reviewed before resolver implementation begins

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Types | PascalCase | `Order`, `PaymentMethod`, `CustomerAddress` |
| Fields | camelCase | `orderDate`, `totalAmount`, `shippingAddress` |
| Enum types | PascalCase | `OrderStatus`, `PaymentType` |
| Enum values | UPPER_SNAKE_CASE | `PENDING`, `IN_PROGRESS`, `COMPLETED` |
| Input types | PascalCase with `Input` suffix | `CreateOrderInput`, `UpdateCustomerInput` |
| Query fields | camelCase, noun or noun phrase | `order`, `orders`, `customerByEmail` |
| Mutation fields | camelCase, verb phrase | `createOrder`, `cancelOrder`, `updateShippingAddress` |
| Subscription fields | camelCase, `on` prefix for events | `onOrderCreated`, `onPaymentProcessed` |
| Interfaces | PascalCase, adjective or noun | `Node`, `Timestamped`, `Auditable` |
| Unions | PascalCase, descriptive | `SearchResult`, `PaymentOutcome` |

## Query Depth and Complexity Limiting

### Depth Limiting

| Setting | Value | Reasoning |
|---------|-------|-----------|
| Maximum query depth | 7 levels | Prevents deeply nested queries that cause N+1 explosions |
| Maximum breadth per level | 20 fields | Prevents overly wide selections |

Reject queries exceeding depth limit with a clear error message before execution.

### Complexity Analysis and Cost Calculation

Assign cost to each field and enforce a maximum total cost per query.

| Field Type | Default Cost | Notes |
|------------|:------------:|-------|
| Scalar field | 0 | Free to resolve (already loaded) |
| Object field (eager) | 1 | Requires resolver invocation |
| Object field (lazy/DB) | 5 | Requires database or service call |
| List field | 5 * estimated items | Multiply by `first`/`last` argument or default page size |
| Connection field | 10 * requested items | Relay connections include edges + nodes |

**Rules:**
- Maximum query cost: 1000 points (configurable per client/tier)
- Return estimated cost in response extensions for client awareness
- Log queries exceeding 80% of the cost limit for monitoring
- Authenticated/premium clients MAY have higher cost limits

## N+1 Prevention with DataLoader

- EVERY resolver that fetches related entities MUST use a DataLoader (or equivalent batching mechanism)
- DataLoaders batch and deduplicate calls within a single request execution context
- Create one DataLoader instance per request per entity type
- NEVER create DataLoaders at application scope (they cache across requests)
- Monitor batch sizes; if consistently 1, the DataLoader is not batching effectively

| Pattern | Correct | Incorrect |
|---------|---------|-----------|
| Load order items for orders | Batch all order IDs, single query | One query per order |
| Load author for articles | Batch all author IDs, single query | One query per article |
| Resolve nested objects | DataLoader at each level | Direct DB call in each resolver |

## Cursor-Based Pagination (Relay Connection Spec)

All list fields MUST use the Relay Connection specification.

**Required types for every connection:**

| Type | Fields | Purpose |
|------|--------|---------|
| `XxxConnection` | `edges`, `pageInfo`, `totalCount` (optional) | Container |
| `XxxEdge` | `node`, `cursor` | Wrapper with position |
| `PageInfo` | `hasNextPage`, `hasPreviousPage`, `startCursor`, `endCursor` | Navigation metadata |

**Arguments:**

| Argument | Type | Description |
|----------|------|-------------|
| `first` | Int | Forward pagination: number of items |
| `after` | String | Forward pagination: cursor after which to start |
| `last` | Int | Backward pagination: number of items |
| `before` | String | Backward pagination: cursor before which to start |

**Rules:**
- NEVER use offset-based pagination in GraphQL (cursors are mandatory)
- Default page size: 20; maximum page size: 100
- `totalCount` is optional; omit if the count query is expensive
- Cursors MUST be opaque (base64-encoded internal identifiers)

## Input Types for Mutations

- Every mutation MUST accept a single `input` argument of a dedicated Input type
- Input type names: `VerbNounInput` (e.g., `CreateOrderInput`, `CancelOrderInput`)
- NEVER reuse the same Input type for create and update -- fields differ (e.g., `id` required for update)
- Input types MUST NOT reference output types (they are separate graphs)
- Validate all input fields; return structured errors in the mutation response

## Union Types for Error Handling (Result Pattern)

Mutations SHOULD return a union type that represents success or typed errors.

**Pattern:**

| Return Union | Members | Purpose |
|-------------|---------|---------|
| `CreateOrderResult` | `CreateOrderSuccess`, `ValidationError`, `NotFoundError` | Typed outcomes |
| `CancelOrderResult` | `CancelOrderSuccess`, `OrderNotCancelableError` | Domain-specific errors |

**Rules:**
- Success type contains the created/updated resource
- Error types contain `message` (String!) and relevant context fields
- NEVER rely solely on top-level GraphQL `errors` array for business logic errors
- Top-level errors are reserved for transport/auth/system failures
- Each error type SHOULD implement a common `Error` interface with `message` field

## Subscription Patterns

| Transport | When to Use | Tradeoffs |
|-----------|-------------|-----------|
| WebSocket (graphql-ws protocol) | Default for browser clients | Widely supported, bidirectional |
| SSE (Server-Sent Events) | Simple unidirectional streams | Simpler, HTTP-compatible, no bidirectional |

**Rules:**
- Subscriptions MUST authenticate on connection init (not per message)
- Include a heartbeat/keep-alive every 30 seconds
- Subscriptions MUST filter events server-side; NEVER send all events to all clients
- Maximum concurrent subscriptions per client: 10 (configurable)
- Document the event payload and frequency for each subscription field

## Nullability Strategy

**Non-null by default.** Mark fields as non-null (`!`) unless there is a specific reason for nullability.

| Nullable When | Non-Null When |
|---------------|---------------|
| Field is genuinely optional in the domain | Field always has a value |
| Field may fail to resolve independently | Field is a scalar derived from the parent |
| Field depends on permission (hidden = null) | Field is a required identifier |
| Field is deprecated and being phased out | Field is part of the connection spec |

**Rules:**
- List fields: use `[Item!]!` (non-null list of non-null items) as the default
- IDs: always `ID!` (non-null)
- Input fields: mark required fields as non-null; optional fields nullable
- NEVER return null for a non-null field -- it propagates null to the parent

## Enum Conventions

- Enum values MUST be UPPER_SNAKE_CASE
- Include a description for every enum type and value
- NEVER remove enum values from a schema in use -- deprecate first
- Order enum values logically (by lifecycle stage, severity, etc.), not alphabetically
- Consider including an `UNKNOWN` value for forward compatibility with new server values

## Custom Scalar Types

| Scalar | Format | Description |
|--------|--------|-------------|
| `DateTime` | ISO 8601 (`2026-02-19T14:30:00Z`) | Timestamp with timezone |
| `Date` | ISO 8601 (`2026-02-19`) | Calendar date without time |
| `URL` | RFC 3986 | Validated URL string |
| `Email` | RFC 5322 | Validated email address |
| `JSON` | Any valid JSON | Escape hatch for unstructured data (use sparingly) |
| `BigInt` | String-encoded integer | For values exceeding 32-bit integer range |
| `Decimal` | String-encoded decimal | For monetary values requiring exact precision |

**Rules:**
- Every custom scalar MUST have a documented format and validation rules
- NEVER use `String` when a custom scalar provides type safety (e.g., use `DateTime` not `String` for timestamps)
- The `JSON` scalar is a last resort; prefer typed schemas whenever possible

## Anti-Patterns (FORBIDDEN)

- Offset-based pagination -- always use cursor-based (Relay Connection spec)
- Mutations without dedicated Input types -- every mutation uses a typed input
- Relying on the top-level `errors` array for business logic -- use Result union types
- Resolvers without DataLoader for related entity fetching -- causes N+1 queries
- Unbounded list fields without pagination -- all lists MUST be connections
- Using `String` for typed data (dates, URLs, emails) -- use custom scalars
- Exposing database IDs directly -- use opaque, globally unique IDs (base64-encoded)
- Deeply nested schemas without depth limiting -- enforce maximum depth of 7
- Queries without complexity/cost analysis -- enforce cost budgets
- Shared input types between create and update mutations
- Nullable fields without a documented reason for nullability
- Schema definitions without descriptions on types and fields
- Subscriptions that broadcast all events to all clients without filtering
