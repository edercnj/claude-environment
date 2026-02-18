# Common Compilation Errors and Resolution Strategies

## Quarkus / CDI Errors

| Error | Cause | Resolution |
|-------|-------|-----------|
| `Unsatisfied dependency for type X` | CDI bean not found | Verify `@ApplicationScoped` on the implementation class |
| `Ambiguous dependencies for type X` | Multiple implementations of same interface | Add `@Priority` or use `@Named` qualifier |
| `No bean found for injection point` | Missing implementation of port interface | Check that the adapter implements the port |

## Panache / JPA Errors

| Error | Cause | Resolution |
|-------|-------|-----------|
| `Not a managed type: class X` | Entity not annotated | Add `@Entity` annotation |
| `Table "X" not found` | Missing migration or wrong table name | Verify Flyway migration and `@Table(name)` |
| `Could not determine type for: X` | Missing `@Column` or wrong type | Add explicit `@Column` with correct type mapping |

## Jackson / REST Errors

| Error | Cause | Resolution |
|-------|-------|-----------|
| `No serializer found for class X` | Missing getter or `@RegisterForReflection` | Add `@RegisterForReflection` on the record |
| `Cannot construct instance of X` | Missing no-arg constructor or not a record | Ensure record is used (auto-constructor) |
| `Unrecognized field "x"` | DTO field name mismatch | Check JSON field naming (camelCase) |

## Hexagonal Architecture Violations

| Error | Cause | Resolution |
|-------|-------|-----------|
| `package com.bifrost.simulator.adapter.X does not exist` in domain | Domain importing adapter | CRITICAL: Restructure — domain must NEVER import adapter |
| `package jakarta.X does not exist` in domain | Domain importing Jakarta | CRITICAL: Remove Jakarta imports from domain layer |

## Common Task Errors by Layer

### Migration (G1)
- **Syntax error in SQL**: Check PostgreSQL-specific syntax, especially `BIGSERIAL`, `TIMESTAMPTZ`
- **Schema not found**: Ensure `CREATE SCHEMA IF NOT EXISTS simulator;` is in earlier migration

### Domain Models (G1)
- **Record component has default value**: Records don't support field defaults — use factory method or builder
- **Sealed interface permits unknown type**: Ensure all `permits` classes exist in same package or are accessible

### Ports (G2)
- **Type not found in port signature**: Domain model from G1 not yet compiled — check G1 completed successfully

### Entity (G3)
- **Column type mismatch**: Verify `@Column` annotations match the migration DDL types

### Repository (G3)
- **PanacheRepository method not found**: Use Panache query DSL (`find("field", value)`)

### Use Case (G4)
- **Port interface not satisfied**: Verify adapter implements the port with `@ApplicationScoped`

### REST Resource (G5)
- **Missing @Valid**: Bean Validation won't trigger without `@Valid` on the parameter
- **Wrong return type**: POST should return `Response` (for 201 + Location), not the entity directly

### TCP Handler (G5)
- **Vert.x event loop blocked**: Long operations must be offloaded to worker thread pool
- **Buffer handling**: Use `Buffer.getUnsignedShort(0)` for 2-byte length prefix

### Tests (G7)
- **AssertJ import conflict**: Use `org.assertj.core.api.Assertions.assertThat`, never JUnit assertions
- **@QuarkusTest port not available**: Use `@ConfigProperty(name = "simulator.socket.port")` + Awaitility
- **Test isolation**: Use `@TestTransaction` or unique IDs (`System.nanoTime()`) to avoid conflicts

## Escalation Indicators

These patterns suggest the task needs a higher-tier model:

1. **Same error after 2 retries** → Haiku likely cannot reason about the fix
2. **Error involves cross-layer interaction** → Needs broader architectural context (Sonnet/Opus)
3. **Error involves resilience patterns** → Circuit breaker, bulkhead, backpressure need Opus
4. **Error involves concurrent/async code** → Thread safety, Vert.x patterns need Sonnet+
5. **Error involves ISO 8583 wire format** → Encoding/decoding nuances need Sonnet+
