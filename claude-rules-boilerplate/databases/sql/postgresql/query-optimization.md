# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# PostgreSQL — Query Optimization

> Index strategies, EXPLAIN ANALYZE patterns, connection pooling, and maintenance for PostgreSQL.

## EXPLAIN ANALYZE Patterns

### Reading an Execution Plan

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM {{DB_TYPE}}.transactions
WHERE merchant_id = 42 AND created_at > '2026-01-01';
```

| Flag      | Purpose                                          |
| --------- | ------------------------------------------------ |
| `ANALYZE` | Actually executes the query (not just estimates) |
| `BUFFERS` | Shows buffer cache hits vs disk reads            |
| `FORMAT TEXT` | Human-readable output (also: JSON, YAML)     |
| `VERBOSE` | Shows column output list per node                |

### Key Metrics to Watch

| Metric                  | Good                     | Bad                           |
| ----------------------- | ------------------------ | ----------------------------- |
| Seq Scan on large table | Only for small tables    | Missing index                 |
| Index Scan              | Expected for filtered queries | — (this is good)         |
| Index Only Scan         | Best case — no heap access | —                           |
| Bitmap Heap Scan        | Multiple index conditions | Consider composite index     |
| Nested Loop             | Small inner set          | Large inner set = slow        |
| Hash Join               | Medium-large sets        | Low `work_mem` causes disk    |
| Sort (external)         | Should be in memory      | Increase `work_mem`           |
| Rows (actual vs planned)| Close to each other      | Stale statistics → `ANALYZE`  |

### Common Patterns

```sql
-- Check if index is used
EXPLAIN ANALYZE SELECT * FROM {{DB_TYPE}}.merchants WHERE mid = '123456789012345';
-- Expected: Index Scan using uq_merchants_mid

-- Check JOIN strategy
EXPLAIN ANALYZE
SELECT t.* FROM {{DB_TYPE}}.transactions t
JOIN {{DB_TYPE}}.merchants m ON m.id = t.merchant_id
WHERE m.mid = '123456789012345';
-- Expected: Nested Loop with Index Scan on both tables

-- Check sort performance
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM {{DB_TYPE}}.transactions
ORDER BY created_at DESC LIMIT 20;
-- Expected: Index Scan Backward (not Sort + Seq Scan)
```

## Index Types — When to Use Each

| Index Type | Best For                              | Not For                      | Example                                    |
| ---------- | ------------------------------------- | ---------------------------- | ------------------------------------------ |
| B-tree     | Equality (`=`), range (`<`, `>`), sorting, `LIKE 'prefix%'` | Full-text, arrays, JSON | `CREATE INDEX idx ON t(col);`             |
| Hash       | Equality only (`=`), large values     | Range queries, sorting       | `CREATE INDEX idx ON t USING hash(col);`  |
| GIN        | Arrays, JSONB, full-text search, trigram | Simple equality/range     | `CREATE INDEX idx ON t USING gin(data);`  |
| GiST       | Geometric, range types, full-text, exclusion constraints | Simple equality | `CREATE INDEX idx ON t USING gist(col);` |
| BRIN       | Large tables with natural ordering (timestamps, serials) | Random access | `CREATE INDEX idx ON t USING brin(created_at);` |

### Decision Table

| Query Pattern                        | Recommended Index                        |
| ------------------------------------ | ---------------------------------------- |
| `WHERE col = value`                  | B-tree (default)                         |
| `WHERE col BETWEEN a AND b`         | B-tree                                   |
| `WHERE col LIKE 'prefix%'`          | B-tree (with `text_pattern_ops` for C locale) |
| `WHERE col LIKE '%substring%'`      | GIN with `pg_trgm`                       |
| `WHERE jsonb_col @> '{"key": "v"}'` | GIN on JSONB column                      |
| `WHERE array_col @> ARRAY[1,2]`     | GIN on array column                      |
| `WHERE col = value` (time-series)    | BRIN (if data is naturally ordered)      |
| `ORDER BY col DESC LIMIT N`         | B-tree (enables Index Scan Backward)     |

## Partial Indexes

Index only the rows that matter:

```sql
-- Only index active merchants (skip DELETED/INACTIVE)
CREATE INDEX idx_merchants_active_mid
    ON {{DB_TYPE}}.merchants (mid)
    WHERE status = 'ACTIVE';

-- Only index recent transactions (skip old data)
CREATE INDEX idx_transactions_recent
    ON {{DB_TYPE}}.transactions (merchant_id, created_at DESC)
    WHERE created_at > '2025-01-01';

-- Only index non-null optional columns
CREATE INDEX idx_transactions_rrn
    ON {{DB_TYPE}}.transactions (retrieval_reference_number)
    WHERE retrieval_reference_number IS NOT NULL;
```

## Covering Indexes (INCLUDE)

Avoid heap access by including extra columns in the index (PostgreSQL 11+):

```sql
-- Index covers the query entirely — Index Only Scan
CREATE INDEX idx_transactions_stan_covering
    ON {{DB_TYPE}}.transactions (stan, local_date_time)
    INCLUDE (response_code, amount);

-- Query satisfied entirely from index:
SELECT response_code, amount
FROM {{DB_TYPE}}.transactions
WHERE stan = '123456' AND local_date_time = '2026-02-18';
```

## Expression Indexes

Index computed values:

```sql
-- Case-insensitive search
CREATE INDEX idx_merchants_name_lower
    ON {{DB_TYPE}}.merchants (LOWER(legal_name));
-- Query: WHERE LOWER(legal_name) = 'test store'

-- Extract from JSONB
CREATE INDEX idx_transactions_jsonb_mcc
    ON {{DB_TYPE}}.transactions ((parsed_fields->>'mcc'));
-- Query: WHERE parsed_fields->>'mcc' = '5411'

-- Date extraction
CREATE INDEX idx_transactions_date
    ON {{DB_TYPE}}.transactions (DATE(created_at));
-- Query: WHERE DATE(created_at) = '2026-02-18'
```

## Connection Pool Configuration

### Quarkus (Agroal)

| Property                                   | Default | Recommended (Production) |
| ------------------------------------------ | ------- | ------------------------ |
| `quarkus.datasource.jdbc.min-size`         | 0       | 5                        |
| `quarkus.datasource.jdbc.max-size`         | 20      | 20                       |
| `quarkus.datasource.jdbc.acquisition-timeout` | 5s   | 5s                       |
| `quarkus.datasource.jdbc.idle-removal-interval` | 5min | 2min                  |
| `quarkus.datasource.jdbc.max-lifetime`     | —       | 30min                    |

### Spring Boot (HikariCP)

| Property                                    | Default | Recommended (Production) |
| ------------------------------------------- | ------- | ------------------------ |
| `spring.datasource.hikari.minimum-idle`     | 10      | 5                        |
| `spring.datasource.hikari.maximum-pool-size`| 10      | 20                       |
| `spring.datasource.hikari.connection-timeout`| 30s    | 5s                       |
| `spring.datasource.hikari.idle-timeout`     | 10min   | 2min                     |
| `spring.datasource.hikari.max-lifetime`     | 30min   | 30min                    |
| `spring.datasource.hikari.leak-detection-threshold` | 0 | 60s                    |

### Pool Sizing Formula

```
pool_size = (core_count * 2) + effective_spindle_count
```

For SSD-based systems: `pool_size = core_count * 2 + 1`. Typically 10-20 connections is sufficient. More connections increase context switching overhead.

## Vacuum and Maintenance

| Operation       | Purpose                                | When                               |
| --------------- | -------------------------------------- | ---------------------------------- |
| `VACUUM`        | Reclaims dead tuples from updates/deletes | Automatic (autovacuum)          |
| `VACUUM FULL`   | Reclaims disk space, rewrites table    | Rarely — locks table exclusively   |
| `ANALYZE`       | Updates statistics for query planner   | Automatic (autovacuum)             |
| `REINDEX`       | Rebuilds bloated indexes               | When index bloat > 30%             |
| `pg_repack`     | Online table/index rewrite (no lock)   | Production-safe alternative to VACUUM FULL |

### Autovacuum Configuration

| Parameter                          | Default | High-Write Tables |
| ---------------------------------- | ------- | ----------------- |
| `autovacuum_vacuum_scale_factor`   | 0.2     | 0.05              |
| `autovacuum_analyze_scale_factor`  | 0.1     | 0.02              |
| `autovacuum_vacuum_cost_delay`     | 2ms     | 0ms (aggressive)  |
| `autovacuum_naptime`               | 1min    | 30s               |

For high-write tables (e.g., `transactions`), set per-table autovacuum:

```sql
ALTER TABLE {{DB_TYPE}}.transactions SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_analyze_scale_factor = 0.02
);
```

## Monitoring Queries

```sql
-- Top 10 slowest queries (requires pg_stat_statements)
SELECT query, calls, mean_exec_time, total_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC LIMIT 10;

-- Index usage statistics
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read
FROM pg_stat_user_indexes
WHERE schemaname = '{{DB_TYPE}}'
ORDER BY idx_scan ASC;

-- Table bloat estimate
SELECT schemaname, tablename, n_dead_tup, n_live_tup,
       ROUND(n_dead_tup::numeric / NULLIF(n_live_tup, 0) * 100, 2) AS dead_pct
FROM pg_stat_user_tables
WHERE schemaname = '{{DB_TYPE}}'
ORDER BY n_dead_tup DESC;

-- Cache hit ratio (should be > 99%)
SELECT ROUND(
    SUM(heap_blks_hit)::numeric / NULLIF(SUM(heap_blks_hit) + SUM(heap_blks_read), 0) * 100, 2
) AS cache_hit_ratio
FROM pg_statio_user_tables;
```

## Anti-Patterns (Query Optimization)

| Anti-Pattern                          | Problem                                    | Correct Approach                        |
| ------------------------------------- | ------------------------------------------ | --------------------------------------- |
| `SELECT *` in production queries      | Fetches unnecessary columns, blocks Index Only Scan | List columns explicitly          |
| Missing index on FK columns           | Full table scan on JOINs                   | Always index foreign keys               |
| `OR` conditions on different columns  | Often prevents index usage                 | Use `UNION ALL` or restructure query    |
| `NOT IN (subquery)` with NULLs       | Returns no rows if subquery has NULLs     | Use `NOT EXISTS` instead                |
| `OFFSET` for deep pagination          | Scans and discards N rows                  | Use keyset/cursor pagination            |
| Functions on indexed columns in WHERE  | Prevents index usage                       | Use expression index or rewrite query   |
| Too many indexes on write-heavy tables | Slows INSERT/UPDATE/DELETE                | Index only what queries need            |
| `DISTINCT` to mask a bad JOIN         | Hides duplicate logic, expensive sort      | Fix the JOIN condition                  |
