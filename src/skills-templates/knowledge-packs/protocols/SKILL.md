---
name: protocols
description: "Protocol conventions: REST (OpenAPI 3.1), gRPC (Proto3), GraphQL, WebSocket, and event-driven messaging. URL structure, versioning, error handling per protocol, schema design, and integration patterns."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Protocols

## Purpose

Provides protocol-specific design and implementation patterns for {{LANGUAGE}} {{FRAMEWORK}}, covering REST, gRPC, GraphQL, WebSocket, and event-driven architectures. Enables consistent API design across multiple protocols while respecting each protocol's idioms and best practices.

## Quick Reference (always in context)

See `skills/api-design/references/api-design-principles.md` for universal API design principles (error handling, pagination, validation). Protocol-specific conventions are in this knowledge pack's `references/` directory.

## Detailed References

Read these files for comprehensive protocol guidance:

| Reference | Content |
|-----------|---------|
| `protocols/rest/rest-conventions.md` | Resource naming (plural nouns, kebab-case), HTTP methods (GET/POST/PUT/PATCH/DELETE) with idempotency, status codes (2xx/3xx/4xx/5xx), RFC 7807 error format, pagination (cursor vs offset), filtering, sorting, versioning strategies (path-based preferred), bulk operations, PATCH strategies (Merge Patch vs JSON Patch), rate limiting headers |
| `protocols/rest/openapi-conventions.md` | OpenAPI 3.1 specification structure, multi-file organization with $ref, required schema documentation, example values (mandatory), security schemes, operation IDs (verbResource pattern), tags for grouping, discriminator for polymorphism, parameter documentation, response documentation including all status codes |
| `protocols/grpc/grpc-conventions.md` | Proto3 language guide, package naming (reverse domain + service + version), service/message/field naming conventions, enum design (zero value = UNSPECIFIED), oneof usage, streaming patterns (unary/server/client/bidirectional), deadline propagation, error codes (gRPC standard codes), health check implementation (grpc.health.v1.Health) |
| `protocols/grpc/grpc-versioning.md` | Package-based versioning (v1, v2, v1alpha1, v1beta1), backward compatibility rules (safe vs unsafe changes), field deprecation lifecycle, reserved field declarations, migration strategies (parallel deployment, gateway translation, coordinated migration), version lifecycle management |
| `protocols/graphql/graphql-conventions.md` | Schema design patterns, query/mutation/subscription naming, input types for complex arguments, interface and union types, error handling (standard GraphQL errors + domain errors), complexity analysis to prevent DoS, DataLoader for N+1 prevention, subscription lifecycle management |
| `protocols/websocket/websocket-conventions.md` | Message framing and serialization, heartbeat/keep-alive mechanisms, reconnection logic with exponential backoff, connection draining (graceful close), error handling over persistent connections, flow control and backpressure, state management |
| `protocols/event-driven/event-conventions.md` | CloudEvents envelope standard (specversion, id, source, type, time, datacontenttype), event naming (reverse domain + past tense), schema registry integration, event versioning (additive vs breaking), correlation ID and causation ID propagation, ordering guarantees per partition key |
| `protocols/event-driven/broker-patterns.md` | Topic naming (domain.entity.event), partition strategies (by entity ID, tenant, region), consumer lag monitoring, producer acknowledgment levels (acks=0/1/all), retention policies per topic type, message schema evolution, compacted topics for state, dead letter topic configuration |
