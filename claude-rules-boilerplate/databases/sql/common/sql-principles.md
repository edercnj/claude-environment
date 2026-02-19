# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# SQL — Universal Principles

> Common principles for all SQL databases. Database-specific conventions are in separate directories.

## DDL Transactional Behavior

| Database   | DDL in Transactions | Behavior                                                     |
| ---------- | ------------------- | ------------------------------------------------------------ |
| PostgreSQL | Transactional       | `CREATE TABLE` inside `BEGIN;...COMMIT;` — rolls back on error |
| MySQL/MariaDB | Implicit commit  | DDL causes implicit `COMMIT` — cannot rollback DDL            |
| Oracle     | Auto-commit         | DDL auto-commits before and after — cannot rollback DDL       |
| SQL Server | Transactional       | DDL inside transactions — rolls back on error                 |
| SQLite     | Transactional       | DDL inside transactions — rolls back on error                 |

> **Impact on migrations:** PostgreSQL and SQL Server allow safe DDL migrations wrapped in transactions. For MySQL/Oracle, each DDL statement is a point of no return.

## ACID Properties and Isolation Levels

| Isolation Level  | Dirty Read | Non-Repeatable Read | Phantom Read | Recommended For                |
| ---------------- | ---------- | ------------------- | ------------ | ------------------------------ |
| READ UNCOMMITTED | Possible   | Possible            | Possible     | Never (avoid)                  |
| READ COMMITTED   | No         | Possible            | Possible     | **Default for most apps**      |
| REPEATABLE READ  | No         | No                  | Possible     | Financial reports, aggregation |
| SERIALIZABLE     | No         | No                  | No           | Critical financial operations  |

**Recommendation:** Use `READ COMMITTED` as default. Escalate to `REPEATABLE READ` or `SERIALIZABLE` only for specific transactions that require it.

| Database   | Default Isolation    | MVCC | Notes                                      |
| ---------- | -------------------- | ---- | ------------------------------------------ |
| PostgreSQL | READ COMMITTED       | Yes  | MVCC-based, no read locks                  |
| MySQL/InnoDB | REPEATABLE READ    | Yes  | Gap locking can cause deadlocks            |
| Oracle     | READ COMMITTED       | Yes  | Uses undo segments for MVCC               |
| SQL Server | READ COMMITTED       | No*  | Lock-based by default, RCSI optional       |

## Locking Strategies

| Strategy              | Mechanism                          | Use Case                           | Trade-off                    |
| --------------------- | ---------------------------------- | ---------------------------------- | ---------------------------- |
| Row-level (pessimistic) | `SELECT ... FOR UPDATE`          | Concurrent updates to same row     | Blocks other transactions    |
| Table-level           | `LOCK TABLE ... IN EXCLUSIVE MODE` | Bulk operations, schema changes    | Blocks all concurrent access |
| Optimistic (version)  | `version` column + check on UPDATE | Low contention, read-heavy apps    | Retry on conflict            |
| Advisory locks        | `pg_advisory_lock()` (PostgreSQL)  | Application-level coordination     | Database-specific            |

### Optimistic Locking Pattern

```sql
-- Add version column
ALTER TABLE {{DB_TYPE}}.orders ADD COLUMN version INTEGER NOT NULL DEFAULT 0;

-- Update with version check
UPDATE {{DB_TYPE}}.orders
SET status = 'SHIPPED', version = version + 1, updated_at = NOW()
WHERE id = :id AND version = :expectedVersion;
-- If rows_affected = 0 -> concurrent modification, retry
```

## Migration Tools — Decision Matrix

| Criterion             | Flyway                              | Liquibase                           |
| --------------------- | ----------------------------------- | ----------------------------------- |
| Format                | Plain SQL files (+ Java callbacks)  | XML, YAML, JSON, or SQL            |
| Learning curve        | Low (just write SQL)                | Medium (changelog format)           |
| Rollback support      | Paid (Teams edition) for auto       | Built-in (free)                     |
| Multi-database        | SQL per database                    | Abstract changelog, generates SQL   |
| CI/CD integration     | Simple (single JAR)                 | More setup required                 |
| Framework integration | Quarkus, Spring Boot, Micronaut     | Spring Boot, Micronaut              |
| Best for              | SQL-first teams, single DB vendor   | Multi-DB support, rollback needed   |
| Naming convention     | `V{N}__{description}.sql`           | `changelog-{N}.xml` or YAML        |

**Recommendation:** Use Flyway for single-database projects where the team writes raw SQL. Use Liquibase when rollback support or multi-database abstraction is required.

## Universal ORM Mapping Patterns

| Concept           | JPA (Java)                  | SQLAlchemy (Python)          | EF Core (C#)                | GORM (Go)              |
| ----------------- | --------------------------- | ---------------------------- | --------------------------- | ---------------------- |
| Entity class      | `@Entity`                   | `class(Base)`                | `class : DbContext`         | `struct` with tags     |
| Primary key       | `@Id @GeneratedValue`       | `Column(primary_key=True)`   | `[Key]`                     | `gorm:"primaryKey"`    |
| Auto-increment    | `@GeneratedValue(IDENTITY)` | `autoincrement=True`         | `ValueGeneratedOnAdd()`     | `gorm:"autoIncrement"` |
| Relationship      | `@ManyToOne` / `@OneToMany` | `relationship()`             | Navigation properties       | `gorm:"foreignKey"`    |
| Repository        | `PanacheRepository<T>`      | `Session.query(T)`           | `DbSet<T>`                  | `db.Find(&T)`          |
| Transactions      | `@Transactional`            | `with session.begin():`      | `SaveChangesAsync()`        | `db.Transaction()`     |
| Schema mapping    | `@Table(schema="...")`      | `__table_args__ = {schema}`  | `ToTable("...", schema)`    | `TableName()`          |

## Anti-Patterns (FORBIDDEN)

| Anti-Pattern                     | Problem                                         | Correct Approach                            |
| -------------------------------- | ------------------------------------------------ | ------------------------------------------- |
| `FLOAT`/`DOUBLE` for money      | Floating-point rounding errors                   | `BIGINT` (cents) or `NUMERIC`/`DECIMAL`     |
| `SELECT *`                       | Returns unnecessary data, breaks on schema change | List columns explicitly                     |
| Missing indexes on FKs           | Full table scans on JOIN operations              | Always index foreign key columns            |
| Composite primary keys           | Complex JOINs, ORM friction, migration headaches | `BIGSERIAL` PK + `UNIQUE` constraint        |
| Storing formatted data           | Inconsistent formatting, wasted space            | Store raw, format on output                 |
| `VARCHAR(255)` everywhere        | Arbitrary limit, misleading schema               | Use meaningful limits or `TEXT`              |
| `NULL` on boolean columns        | Three-state logic (true/false/unknown)           | `BOOLEAN NOT NULL DEFAULT FALSE`            |
| No `updated_at` column           | No audit trail, cache invalidation impossible    | Always add `created_at` and `updated_at`    |
| Modifying applied migrations     | Breaks checksum validation, corrupts state       | Create a new migration                      |
| Storing full PAN/PIN/CVV         | PCI-DSS violation, security breach risk          | Mask or never persist sensitive data        |
