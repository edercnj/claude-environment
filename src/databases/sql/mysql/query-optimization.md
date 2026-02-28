# MySQL / MariaDB — Query Optimization

## Index Types

| Type | Use Case | Syntax | Notes |
|------|----------|--------|-------|
| B-tree | Default; equality, range, ORDER BY, GROUP BY | `CREATE INDEX idx ON t(col)` | InnoDB default |
| Composite | Multi-column WHERE/ORDER BY | `CREATE INDEX idx ON t(col1, col2)` | Leftmost prefix rule applies |
| Covering | Query answered entirely from index | `CREATE INDEX idx ON t(col1, col2, col3)` | Avoids table lookup; watch `INCLUDE` in 8.0+ |
| Fulltext | Text search (`MATCH ... AGAINST`) | `CREATE FULLTEXT INDEX idx ON t(col)` | InnoDB 5.6+; natural language or boolean mode |
| Spatial | GIS data (`ST_Contains`, `ST_Distance`) | `CREATE SPATIAL INDEX idx ON t(geo_col)` | Column must be `NOT NULL`, SRID defined |
| Prefix | Long VARCHAR columns | `CREATE INDEX idx ON t(col(20))` | First N characters only |
| Descending (8.0+) | DESC ordering without filesort | `CREATE INDEX idx ON t(col1 ASC, col2 DESC)` | MySQL 8.0+ only |
| Invisible (8.0+) | Test index removal impact | `ALTER TABLE t ALTER INDEX idx INVISIBLE` | Optimizer ignores; can make VISIBLE again |

## Covering Index Strategy

A covering index contains all columns the query needs, avoiding a table row lookup:

```sql
-- Query
SELECT merchant_id, response_code, created_at
FROM transactions
WHERE merchant_id = 123 AND created_at > '2025-01-01';

-- Covering index (all queried columns in the index)
CREATE INDEX idx_transactions_covering
    ON transactions (merchant_id, created_at, response_code);
```

Check `Extra: Using index` in EXPLAIN output to confirm covering index usage.

## EXPLAIN Analysis

| Format | Command | Best For |
|--------|---------|----------|
| Traditional | `EXPLAIN SELECT ...` | Quick overview |
| JSON | `EXPLAIN FORMAT=JSON SELECT ...` | Detailed cost analysis |
| TREE (8.0.18+) | `EXPLAIN FORMAT=TREE SELECT ...` | Execution flow visualization |
| ANALYZE (8.0.18+) | `EXPLAIN ANALYZE SELECT ...` | Actual vs estimated rows |

### Key EXPLAIN Fields

| Field | Watch For |
|-------|-----------|
| `type` | `ALL` = full table scan (bad); `ref`/`range`/`const` = good |
| `key` | `NULL` = no index used |
| `rows` | High number with small result set = missing/wrong index |
| `Extra: Using filesort` | Missing index for ORDER BY |
| `Extra: Using temporary` | Missing index for GROUP BY / DISTINCT |
| `Extra: Using index` | Covering index (optimal) |
| `Extra: Using index condition` | Index Condition Pushdown (ICP) — good |

```sql
-- Example analysis
EXPLAIN FORMAT=JSON
SELECT m.mid, COUNT(t.id) AS tx_count
FROM merchants m
JOIN transactions t ON t.merchant_id = m.id
WHERE t.created_at > '2025-01-01'
GROUP BY m.mid
ORDER BY tx_count DESC
LIMIT 10;
```

## Slow Query Log

```ini
# my.cnf / my.ini
[mysqld]
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1          # Seconds (use 0.5 for stricter)
log_queries_not_using_indexes = 1
log_slow_admin_statements = 1
```

| Parameter | Recommended | Notes |
|-----------|-------------|-------|
| `long_query_time` | `1` (prod), `0.5` (staging) | Seconds threshold |
| `log_queries_not_using_indexes` | `ON` in staging, `OFF` in prod | Can be noisy in production |
| Analysis tool | `pt-query-digest` (Percona Toolkit) | Aggregates slow log patterns |

Runtime enable without restart: `SET GLOBAL slow_query_log = 1; SET GLOBAL long_query_time = 1;`

## Connection Pool — HikariCP

| Parameter | Setting | Notes |
|-----------|---------|-------|
| `maximumPoolSize` | 20 | Per application instance |
| `minimumIdle` | 5 | Warm connections |
| `connectionTimeout` | 5000 | Milliseconds to wait for connection |
| `idleTimeout` | 300000 | 5 minutes; must be < MySQL `wait_timeout` |
| `maxLifetime` | 1800000 | 30 minutes; must be < MySQL `wait_timeout` |
| `validationTimeout` | 3000 | Health check timeout |
| `connectionTestQuery` | `SELECT 1` | Validation query |

### MySQL Server Timeouts

| Server Variable | Default | Recommended |
|----------------|---------|-------------|
| `wait_timeout` | 28800 (8h) | 3600 (1h) — reduce for connection hygiene |
| `interactive_timeout` | 28800 | 3600 |
| `max_connections` | 151 | Instances * pool_max + admin headroom |
| `innodb_lock_wait_timeout` | 50 | 10-30 for OLTP |

### Quarkus Configuration

```properties
quarkus.datasource.db-kind=mysql
quarkus.datasource.jdbc.url=jdbc:mysql://host:3306/app_db?useSSL=true&serverTimezone=UTC&characterEncoding=utf8mb4
quarkus.datasource.jdbc.min-size=5
quarkus.datasource.jdbc.max-size=20
quarkus.datasource.jdbc.acquisition-timeout=5S
quarkus.datasource.jdbc.idle-removal-interval=5M
quarkus.datasource.jdbc.max-lifetime=30M
```

### Spring Boot Configuration

```yaml
spring:
  datasource:
    url: jdbc:mysql://host:3306/app_db?useSSL=true&serverTimezone=UTC&characterEncoding=utf8mb4
    driver-class-name: com.mysql.cj.jdbc.Driver
    hikari:
      minimum-idle: 5
      maximum-pool-size: 20
      connection-timeout: 5000
      idle-timeout: 300000
      max-lifetime: 1800000
      connection-test-query: SELECT 1
```

## InnoDB Buffer Pool

Set `innodb_buffer_pool_size` to 70-80% of available RAM on dedicated DB servers. Use `innodb_buffer_pool_instances` = 1 per GB to reduce mutex contention.

## Anti-Patterns

- `SELECT *` — prevents covering index optimization
- `LIKE '%prefix'` — cannot use index (leading wildcard)
- `FORCE INDEX` without benchmark — brittle as data changes
- `ORDER BY RAND()` on large tables — full table scan + filesort
- `wait_timeout` shorter than pool `maxLifetime` — causes broken pipe errors
- `innodb_buffer_pool_size` at default (128M) — severely limits performance
