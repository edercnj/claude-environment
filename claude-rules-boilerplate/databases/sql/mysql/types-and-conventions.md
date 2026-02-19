# MySQL / MariaDB — Types and Conventions

## Version Matrix

| Version | Status | Key Features |
|---------|--------|-------------|
| MySQL 8.0 | GA (EOL Apr 2026) | CTEs, Window functions, JSON enhancements, `CHECK` constraints |
| MySQL 8.4 LTS | LTS (until 2032) | Firewall improvements, InnoDB cluster enhancements |
| MySQL 9.x | Innovation | JavaScript stored programs, vector type (preview) |
| MariaDB 10.11 | LTS (until 2028) | System-versioned tables, Oracle compatibility mode |
| MariaDB 11.x | Short-term | Native vector type, JSON improvements |

### MySQL vs MariaDB Key Differences

| Feature | MySQL 8.x | MariaDB 11.x |
|---------|-----------|-------------|
| JSON storage | Binary (optimized) | Text-based (slower) |
| CTEs | Supported | Supported + recursive optimization |
| System versioning | No | Native (`WITH SYSTEM VERSIONING`) |
| CHECK constraints | Enforced (8.0.16+) | Enforced |
| Default auth plugin | `caching_sha2_password` | `mysql_native_password` |
| GIS/Spatial | Good | Better (some extensions) |
| Sequence objects | No | Yes (`CREATE SEQUENCE`) |

## CRITICAL: Character Set

**ALWAYS use `utf8mb4`. NEVER use `utf8`.**

MySQL's `utf8` is actually `utf8mb3` (max 3 bytes) and cannot store emojis or many CJK characters. `utf8mb4` is true UTF-8 (4 bytes).

```sql
-- Database level
CREATE DATABASE app_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Table level (enforced)
CREATE TABLE merchants (
    ...
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

## Storage Engine

**InnoDB is MANDATORY.** Never use MyISAM, MEMORY, or ARCHIVE for application tables.

| Feature | InnoDB | MyISAM |
|---------|--------|--------|
| Transactions | Yes | No |
| Row-level locking | Yes | Table-level only |
| Foreign keys | Yes | No |
| Crash recovery | Yes | No |
| Full-text search | Yes (5.6+) | Yes |

## Type Mapping

| Data | MySQL Type | Notes |
|------|-----------|-------|
| Primary Key | `BIGINT AUTO_INCREMENT` | 64-bit; always `UNSIGNED` optional |
| String (bounded) | `VARCHAR(N)` | Max 65,535 bytes per row total |
| String (unbounded) | `TEXT` / `MEDIUMTEXT` | Cannot have default value |
| Integer | `INT` / `BIGINT` | `TINYINT`, `SMALLINT`, `MEDIUMINT` also available |
| Monetary (cents) | `BIGINT` | NEVER `FLOAT` / `DOUBLE` / `DECIMAL` for cents |
| Boolean | `BOOLEAN` (alias for `TINYINT(1)`) | 0=false, 1=true |
| Timestamp (TZ-aware) | `TIMESTAMP` | UTC-converted; range 1970-2038 |
| Timestamp (no TZ) | `DATETIME(6)` | No conversion; microsecond precision |
| Date only | `DATE` | No time component |
| Binary | `BINARY(N)` / `VARBINARY(N)` / `BLOB` | `BINARY(16)` for UUIDs |
| JSON | `JSON` (MySQL 8+) | Binary storage; validated on insert |
| UUID | `BINARY(16)` + `BIN_TO_UUID()`/`UUID_TO_BIN()` | MySQL 8.0+; ordered for index performance |
| Enum | `VARCHAR(20)` | Prefer VARCHAR over MySQL `ENUM` type (schema change = ALTER TABLE) |

## UUID Storage (MySQL 8.0+)

```sql
-- Store as BINARY(16), ordered for index performance
CREATE TABLE entities (
    id BINARY(16) NOT NULL DEFAULT (UUID_TO_BIN(UUID(), 1)) PRIMARY KEY,
    ...
);

-- Query with readable UUID
SELECT BIN_TO_UUID(id, 1) AS id FROM entities WHERE id = UUID_TO_BIN('...', 1);
```

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Database | `snake_case` | `app_database` |
| Table | `snake_case`, plural, lowercase | `transactions`, `merchants` |
| Column | `snake_case`, lowercase | `response_code`, `created_at` |
| Index | `idx_{table}_{cols}` | `idx_transactions_stan_date` |
| Unique | `uq_{table}_{col}` | `uq_merchants_mid` |
| Foreign Key | `fk_{table}_{ref}` | `fk_terminals_merchant_id` |
| Check | `ck_{table}_{rule}` | `ck_transactions_amount_positive` |

## Framework Integration

| Framework | Dependency | Notes |
|-----------|-----------|-------|
| Quarkus + MySQL | `quarkus-jdbc-mysql` | DevServices: MySQL container auto |
| Quarkus + MariaDB | `quarkus-jdbc-mariadb` | Separate driver/extension |
| Spring Boot | `spring-boot-starter-data-jpa` + `mysql-connector-j` | HikariCP default pool |
| Flyway | `flyway-mysql` | Add-on module for MySQL/MariaDB |
| Liquibase | Built-in MySQL support | Works for both MySQL and MariaDB |

## Anti-Patterns

- `utf8` charset — ALWAYS `utf8mb4`
- `MyISAM` engine — ALWAYS `InnoDB`
- `FLOAT`/`DOUBLE` for money — use `BIGINT` cents
- MySQL `ENUM` type — use `VARCHAR` (schema changes need ALTER TABLE)
- `TIMESTAMP` for dates beyond 2038 — use `DATETIME(6)`
- Missing `ENGINE=InnoDB` in CREATE TABLE — always explicit
- `utf8mb4_general_ci` collation — use `utf8mb4_unicode_ci` (more correct sorting)
