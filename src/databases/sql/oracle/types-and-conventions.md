# Oracle — Types and Conventions

## Version Matrix

| Version | Status | Key Features |
|---------|--------|-------------|
| 19c (19.3+) | LTS until 2027 | JSON in CLOB, 128-char identifiers (12.2+), Automatic Indexing |
| 21c | Innovation | Native JSON type, Blockchain tables, SQL macros, APPROX functions |
| 23ai Free | Latest | Native BOOLEAN, JSON Relational Duality, Schema-level privileges, AI Vector Search |

## Type Mapping

| Data | Oracle Type | Notes |
|------|------------|-------|
| Primary Key | `NUMBER(19)` | 64-bit equivalent; pair with SEQUENCE or IDENTITY |
| String (bounded) | `VARCHAR2(N CHAR)` | Always use `CHAR` semantics for multi-byte safety |
| String (unbounded) | `CLOB` | Max 4 GB; avoid for indexed columns |
| Integer | `NUMBER(10)` / `NUMBER(19)` | No native `INT` storage — `NUMBER` is universal |
| Monetary (cents) | `NUMBER(19)` | NEVER use `FLOAT` or `BINARY_DOUBLE` |
| Boolean | `BOOLEAN` (23ai+) / `NUMBER(1)` (pre-23ai) | Pre-23ai: 0=false, 1=true, add CHECK constraint |
| Timestamp | `TIMESTAMP WITH TIME ZONE` | Always with timezone |
| Date only | `DATE` | Includes time component (Oracle quirk) — use `TRUNC()` |
| Binary | `RAW(N)` (<=2000 bytes) / `BLOB` | `RAW(16)` for UUIDs |
| JSON | `JSON` (21c+) / `CLOB` + IS JSON check (pre-21c) | Native JSON has OSON binary format — faster |
| UUID | `RAW(16)` | Use `SYS_GUID()` or `RAWTOHEX(SYS_GUID())` |

## BOOLEAN Support

| Version | Approach |
|---------|----------|
| 23ai+ | `col_name BOOLEAN NOT NULL DEFAULT FALSE` |
| Pre-23ai | `col_name NUMBER(1) DEFAULT 0 NOT NULL CHECK (col_name IN (0, 1))` |

## JSON Support

| Version | Approach |
|---------|----------|
| 23ai | `JSON` type + JSON Relational Duality views |
| 21c | `JSON` native type, `JSON_VALUE`, `JSON_TABLE`, dot notation |
| 19c | `CLOB CHECK (col IS JSON)` + JSON functions |
| Pre-19c | `CLOB` — manual JSON handling, limited SQL/JSON support |

## Identifier Length

| Version | Max Length |
|---------|-----------|
| 12.2+ | 128 bytes |
| Pre-12.2 | 30 bytes — plan names accordingly |

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Table | `UPPER_CASE` plural or `lower_case` plural | `TRANSACTIONS` or `transactions` |
| Column | Match table convention | `RESPONSE_CODE` or `response_code` |
| Index | `IDX_{TABLE}_{COLS}` | `IDX_TRANSACTIONS_STAN_DATE` |
| Unique | `UQ_{TABLE}_{COL}` | `UQ_MERCHANTS_MID` |
| Foreign Key | `FK_{TABLE}_{REF}` | `FK_TERMINALS_MERCHANT_ID` |
| Sequence | `SEQ_{TABLE}` or `{TABLE}_SEQ` | `SEQ_TRANSACTIONS` |
| Schema | Application-specific | `APP_DATA`, `SIMULATOR` |

Oracle folds unquoted identifiers to UPPERCASE. Use quoted identifiers (`"lower_case"`) only if the project mandates lowercase — avoid mixing.

## Framework Integration

| Framework | Dependency | Notes |
|-----------|-----------|-------|
| Quarkus | `quarkus-jdbc-oracle` | DevServices: `quay.io/devservices/oracle-free:23ai` |
| Spring Boot | `ojdbc11` + `spring-boot-starter-data-jpa` | Use Oracle UCP over HikariCP for RAC/DG |
| Flyway | `flyway-database-oracle` | Add-on module required |
| Liquibase | Built-in Oracle support | Better rollback support than Flyway for Oracle |

## Connection Pool — Oracle UCP

```properties
# Quarkus with Oracle UCP
quarkus.datasource.jdbc.driver=oracle.jdbc.OracleDriver
quarkus.datasource.jdbc.url=jdbc:oracle:thin:@//host:1521/service
quarkus.datasource.jdbc.min-size=5
quarkus.datasource.jdbc.max-size=20
quarkus.datasource.jdbc.acquisition-timeout=5S
```

## MariaDB Is NOT Oracle

MariaDB is a separate open-source RDBMS forked from MySQL. It has no relation to Oracle Database. Use the MySQL/MariaDB reference files for MariaDB projects.

## Anti-Patterns

- `FLOAT` / `BINARY_DOUBLE` for money — use `NUMBER(19)` cents
- `VARCHAR2(4000)` as default — size columns to actual data
- Unquoted mixed-case identifiers — Oracle folds to UPPER
- `DATE` when you need timezone — use `TIMESTAMP WITH TIME ZONE`
- `CHAR(N)` for variable-length data — use `VARCHAR2`
- Ignoring `CHAR` vs `BYTE` semantics — always specify `VARCHAR2(N CHAR)`
