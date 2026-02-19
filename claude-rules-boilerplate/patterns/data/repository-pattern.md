# Repository Pattern

## Intent

The Repository pattern provides a collection-like interface for accessing domain objects, encapsulating the logic required to retrieve, persist, and query data from the underlying storage mechanism. It mediates between the domain layer and the data mapping layer, enabling the domain to work with in-memory collections of objects without knowledge of how those objects are stored. This keeps the domain clean, the data access testable, and the storage technology replaceable.

## When to Use

- Any application following hexagonal or clean architecture where data access must be abstracted
- When domain logic must remain independent of the persistence technology (SQL, NoSQL, file, API)
- Systems where data access patterns need to be testable with in-memory implementations
- When multiple data sources exist and the domain should not know which source is used
- Reference: `core/11-database-principles.md` establishes the repository as the standard data access pattern

## When NOT to Use

- Trivial CRUD applications where the ORM's built-in data access is sufficient
- One-off scripts or batch jobs where a direct query is simpler and maintainability is not a concern
- When the application has no domain layer (pure data pipeline or ETL)
- Read-heavy analytics workloads where repositories add unnecessary abstraction over direct queries

## Structure

```
    Domain Layer                        Adapter Layer
    ┌─────────────────────┐             ┌─────────────────────────┐
    │                     │             │                         │
    │  Domain Model       │             │  ORM Entity             │
    │  (Immutable)        │             │  (Mutable, annotated)   │
    │                     │             │                         │
    │  Repository Port    │             │  Repository Impl        │
    │  (Interface)        │◄────────────┤  (Implements Port)      │
    │                     │             │                         │
    │                     │             │  Entity Mapper          │
    │                     │             │  (Entity <-> Domain)    │
    │                     │             │                         │
    └─────────────────────┘             └─────────────────────────┘

    Call Flow:
    Use Case ──► Repository Port ──► Repository Impl ──► ORM/DB
                 (domain layer)       (adapter layer)
                                            │
                                            ▼
                                      Entity Mapper
                                      (Entity ──► Domain Model)
```

## Implementation Guidelines

### Repository Interface Design

| Principle | Guideline |
|-----------|-----------|
| Location | Repository interfaces (ports) live in the domain layer |
| Parameters | Accept and return domain models only; never ORM entities or DTOs |
| Naming | Name after the aggregate root: OrderRepository, not OrderDAO |
| Granularity | One repository per aggregate root; not per table |
| Return types | Use Optional for single-result queries; never return null |
| Collections | Return immutable collections from query methods |

### Standard Query Methods

| Method Category | Purpose | Naming Convention |
|----------------|---------|-------------------|
| Find by ID | Retrieve single entity by primary key | findById(id) -> Optional |
| Find by criteria | Retrieve entities matching conditions | findByStatus(status) -> List |
| Exists check | Check if entity exists without loading | existsById(id) -> boolean |
| Count | Count entities matching criteria | countByStatus(status) -> long |
| Save | Persist a new or updated entity | save(entity) -> Entity |
| Delete | Remove an entity | deleteById(id) -> void |

### Pagination Guidelines

| Aspect | Guideline |
|--------|-----------|
| Default page size | Define a reasonable default (20-50); never return unbounded results |
| Maximum page size | Enforce a ceiling (100-500); reject requests exceeding it |
| Cursor vs offset | Prefer cursor-based pagination for large datasets; offset-based for small, stable datasets |
| Sort stability | Always include a unique field (ID) in the sort to ensure stable ordering across pages |
| Return metadata | Include total count (if feasible), page size, current page/cursor, has-next indicator |

### Specification Pattern (Advanced Queries)

For complex, composable queries, the Specification pattern separates query criteria from the repository:

| Aspect | Guideline |
|--------|-----------|
| Purpose | Encapsulate query criteria as first-class objects that can be combined |
| Composition | Support AND, OR, NOT composition of specifications |
| Location | Specifications live in the domain layer (they express domain-level criteria) |
| Translation | The repository implementation translates specifications into storage-native queries |
| Use when | Query criteria are dynamic, user-driven, or reused across multiple contexts |

### Implementation Layer Guidelines

| Principle | Detail |
|-----------|--------|
| Entity mapping | Convert between domain models and ORM entities at the repository boundary |
| Transaction awareness | Repositories participate in transactions but do not manage them (Unit of Work manages transactions) |
| Query optimization | Implement efficient queries (proper indexes, fetch strategies) inside the repository implementation |
| Caching | Repository implementations may cache results transparently; the domain is unaware of caching |
| Exception translation | Convert storage-specific exceptions into domain-defined exceptions |

### Anti-Patterns

| Anti-Pattern | Problem | Solution |
|-------------|---------|----------|
| Leaking ORM entities | Domain depends on persistence framework | Map to domain models at the boundary |
| God repository | One repository with methods for every query pattern | One repository per aggregate; use specifications for complex queries |
| Business logic in repository | Validation or rules inside query methods | Keep business logic in domain services |
| Returning mutable collections | Callers can modify the collection | Return unmodifiable or copied collections |
| SELECT * in queries | Fetches unnecessary data; performance waste | Select only required columns |
| No pagination on list queries | Unbounded result sets crash the application | Always paginate list queries |

## Relationship to Other Patterns

- **Reference**: `core/11-database-principles.md` establishes the repository as the standard data access abstraction
- **Hexagonal Architecture**: The repository interface is an outbound port; the implementation is an outbound adapter
- **Unit of Work**: Manages transaction boundaries that span multiple repository operations
- **CQRS**: Write-side repositories handle command persistence; read-side may use specialized query repositories or direct projections
- **Cache-Aside**: The repository implementation may incorporate cache-aside logic transparently
- **Specification Pattern**: Composes complex query criteria as domain objects that repositories can translate to storage queries
