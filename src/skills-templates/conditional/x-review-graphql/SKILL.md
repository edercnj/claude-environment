---
name: x-review-graphql
description: "Skill: GraphQL Schema & Resolver Review — Validates GraphQL schema design, resolver implementation, security patterns, and observability."
allowed-tools: Read, Grep, Glob, Bash
argument-hint: "[schema-file or resolver-name]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: GraphQL Schema & Resolver Review

## Description

Reviews GraphQL schema design, resolver implementation, security patterns, and observability for compliance with best practices including Relay Connection spec, query complexity limiting, and N+1 prevention.

**Condition**: This skill applies when the project uses GraphQL protocol (`interfaces` contains `type: graphql`).

## Prerequisites

- GraphQL schema files (`*.graphqls`, `*.gql`) or code-first schema definitions exist
- GraphQL framework dependency is configured
- Resolver classes/functions are implemented

## Execution Flow

1. **Discover schema files** — Scan for `*.graphqls`, `*.gql`, or code-first schema definitions:
   - List all types, queries, mutations, and subscriptions
   - Identify input types and custom scalars

2. **Discover resolvers** — Scan for resolver classes/functions:
   - Map resolvers to schema types
   - Identify DataLoader usage

3. **Validate schema design** — Check each type/operation:
   - Naming conventions (PascalCase types, camelCase fields, UPPER_SNAKE_CASE enums)
   - Pagination patterns (Relay Connection spec)
   - Mutation input/payload design
   - Subscription lifecycle

4. **Validate resolver patterns** — Check implementation:
   - DataLoader for N+1 prevention
   - Complexity and depth limiting
   - Field-level authorization
   - Error handling

5. **Validate security** — Check security patterns:
   - Authentication on entry points
   - Introspection disabled in production
   - No sensitive data in errors

6. **Generate report** — Summarize findings as checklist:
   - List compliant items
   - List violations with file paths and line numbers
   - Suggest fixes for each violation

## Usage Examples

```
/x-review-graphql schema.graphqls
/x-review-graphql TransactionResolver
/x-review-graphql
```

## Schema Design Checklist (14 points)

### Naming & Types (1-5)
1. Types use PascalCase (`Transaction`, `PaymentMethod`)
2. Fields use camelCase (`transactionId`, `createdAt`)
3. Enums use UPPER_SNAKE_CASE (`PAYMENT_APPROVED`, `PAYMENT_DENIED`)
4. Input types suffixed with `Input` (`CreateTransactionInput`)
5. Mutation payloads suffixed with `Payload` (`CreateTransactionPayload`)

### Query Design (6-9)
6. Cursor-based pagination for lists (Relay Connection spec: `edges`, `node`, `pageInfo`, `cursor`)
7. No nested queries deeper than 4 levels without justification
8. Nullable vs non-null strategy consistent (non-null by default, nullable where absence is valid)
9. Custom scalars for domain types (`DateTime`, `Money`, `Email`)

### Mutation Design (10-12)
10. Mutations accept single `input` argument (not multiple args)
11. Mutation payloads include both `result` and `errors` fields (union type for errors)
12. Idempotency key pattern for critical mutations (`clientMutationId`)

### Subscription Design (13-14)
13. Subscriptions have clear lifecycle (start, data, complete, error)
14. Subscription filters prevent over-broadcasting (topic-based filtering)

## Resolver Checklist (10 points)

### Performance (15-19)
15. DataLoader used for batch loading (N+1 prevention)
16. Complexity analysis configured (max query complexity limit)
17. Depth limiting configured (max depth 10-15)
18. Field-level resolvers are lazy (not pre-loading unused fields)
19. Database queries scoped to requested fields only (projection)

### Security (20-22)
20. Authentication on schema entry points (Query, Mutation, Subscription)
21. Field-level authorization for sensitive data
22. Introspection disabled in production

### Error Handling (23-24)
23. Errors follow GraphQL spec (`errors` array with `message`, `locations`, `path`, `extensions`)
24. Domain errors use union types or `extensions.code` (not just string messages)

## Observability Checklist (4 points)

25. Trace spans per resolver execution
26. Metrics: query complexity, execution time, error rate per operation
27. Structured logging: operation name, variables (masked), duration
28. No sensitive data in error messages, traces, or logs

## Review Checklist

- [ ] Types use PascalCase, fields use camelCase
- [ ] Cursor-based pagination (Relay Connection spec)
- [ ] Query depth and complexity limiting configured
- [ ] DataLoader used for N+1 prevention
- [ ] Mutations accept single input argument
- [ ] Introspection disabled in production
- [ ] Field-level authorization for sensitive data
- [ ] Errors follow GraphQL spec
- [ ] OTel trace spans per resolver
- [ ] No sensitive data in error messages or logs

## Output Format

```
## GraphQL Review — [Schema/Change Description]

### Schema Quality: HIGH / MEDIUM / LOW
### Resolver Quality: HIGH / MEDIUM / LOW

### Schema Findings
1. [Finding with file, line, issue, fix]

### Resolver Findings
1. [Finding with file, line, issue, fix]

### Security Findings
1. [Finding with severity, issue, fix]

### Checklist Results
[Items that passed / failed / not applicable]

### Verdict: APPROVE / REQUEST CHANGES
```

## Rules
- REQUEST CHANGES if N+1 detected without DataLoader
- REQUEST CHANGES if no query depth/complexity limiting
- REQUEST CHANGES if introspection enabled in production config
- REQUEST CHANGES if sensitive data exposed without field-level auth
- Verify pagination follows Relay Connection spec
