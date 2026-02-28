---
name: api-design
description: "API design principles: {{LANGUAGE}}-specific patterns for REST/gRPC/GraphQL. URL structure, status codes, RFC 7807 errors, pagination, content negotiation, validation, request/response shaping, versioning strategies, and protocol conventions."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: API Design

## Purpose

Provides comprehensive API design patterns for {{LANGUAGE}} {{FRAMEWORK}}, covering REST, gRPC, GraphQL, and WebSocket protocols. Includes URL structure conventions, HTTP status codes, RFC 7807 error handling, pagination strategies, content negotiation, input validation, and protocol-specific best practices.

## Quick Reference (always in context)

See `references/api-design-principles.md` for the essential API design summary (URL structure, status codes, error format, pagination).

## Detailed References

Read these files for protocol-specific conventions:

| Reference | Content |
|-----------|---------|
| `protocols/rest/rest-conventions.md` | REST resource naming, HTTP methods, status codes, pagination (cursor vs offset), filtering, sorting, HATEOAS decision guide, error responses |
| `protocols/rest/openapi-conventions.md` | OpenAPI 3.1 specification format, schema organization, $ref reuse, example values, security schemes, operation IDs, tags, discriminator for polymorphism |
| `protocols/grpc/grpc-conventions.md` | Proto3 style guide, package/service/message naming, field conventions, enum design, oneof usage, streaming patterns, deadline propagation, error codes, health checks |
| `protocols/grpc/grpc-versioning.md` | Package-based versioning (v1, v2), backward compatibility rules, field deprecation, reserved fields, migration strategies, version lifecycle |
| `protocols/graphql/graphql-conventions.md` | Schema design, query patterns, mutation naming, subscription patterns, error handling, complexity analysis, DataLoader for N+1 prevention |
| `protocols/websocket/websocket-conventions.md` | Message framing, heartbeat/keep-alive, reconnection logic, connection draining, error handling over persistent connections |
| `protocols/event-driven/event-conventions.md` | CloudEvents envelope, event naming (reverse domain + past tense), schema registry, event versioning, correlation IDs, ordering guarantees |
| `protocols/event-driven/broker-patterns.md` | Topic naming, partition strategies, consumer lag monitoring, producer acknowledgments, retention policies, schema evolution, dead letter topics |
