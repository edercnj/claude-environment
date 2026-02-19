# Oracle — Query Optimization

## Index Types

| Type | Use Case | Syntax |
|------|----------|--------|
| B-tree | Default; equality, range, ORDER BY | `CREATE INDEX idx ON t(col)` |
| Bitmap | Low-cardinality columns (status, type); OLAP/DW | `CREATE BITMAP INDEX idx ON t(col)` |
| Function-based | Queries on expressions (`UPPER()`, `TRUNC()`) | `CREATE INDEX idx ON t(UPPER(col))` |
| Composite | Multi-column WHERE; most selective first | `CREATE INDEX idx ON t(col1, col2)` |
| INVISIBLE | Test index impact without affecting optimizer | `CREATE INDEX idx ON t(col) INVISIBLE` |
| Reverse Key | Sequence-generated PKs on RAC (avoids hot blocks) | `CREATE INDEX idx ON t(col) REVERSE` |
| Partial (21c+) | Index only active/relevant rows | `CREATE INDEX idx ON t(col) WHERE status = 'ACTIVE'` |

## Bitmap Index Restrictions

- NEVER on OLTP tables with concurrent DML — causes severe locking
- Use only for read-heavy/DW workloads
- Bitmap indexes lock entire bitmap segments, not individual rows

## Partitioning

| Strategy | Use Case | Example |
|----------|----------|---------|
| Range | Date-based data (transactions by month) | `PARTITION BY RANGE (created_at)` |
| List | Status/region-based | `PARTITION BY LIST (region)` |
| Hash | Even distribution when no natural range | `PARTITION BY HASH (id) PARTITIONS 8` |
| Interval | Auto-create range partitions on insert | `INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))` |
| Composite | Range-Hash, Range-List | Large tables needing two-level partitioning |

```sql
CREATE TABLE app_schema.transactions (
    id NUMBER(19) GENERATED ALWAYS AS IDENTITY,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    amount_cents NUMBER(19) NOT NULL
)
PARTITION BY RANGE (created_at)
INTERVAL (NUMTOYMINTERVAL(1, 'MONTH'))
(
    PARTITION p_initial VALUES LESS THAN (TIMESTAMP '2025-01-01 00:00:00 +00:00')
);
```

## Execution Plans

| Tool | Purpose | Command |
|------|---------|---------|
| `EXPLAIN PLAN` | Estimated plan without executing | `EXPLAIN PLAN FOR SELECT ...; SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);` |
| `DBMS_XPLAN.DISPLAY_CURSOR` | Actual plan after execution | `SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));` |
| AWR (Automatic Workload Repository) | Historical query performance | `@$ORACLE_HOME/rdbms/admin/awrrpt.sql` |
| ASH (Active Session History) | Real-time session analysis | `SELECT * FROM V$ACTIVE_SESSION_HISTORY WHERE sql_id = '...'` |
| SQL Monitor | Real-time execution monitoring (19c+) | `DBMS_SQL_MONITOR.REPORT_SQL_MONITOR(sql_id => '...')` |

### Key Plan Operations to Watch

| Operation | Warning Sign |
|-----------|-------------|
| `TABLE ACCESS FULL` | Missing index or index not used |
| `NESTED LOOPS` on large sets | Consider HASH JOIN |
| `SORT ORDER BY` | Missing index for ORDER BY |
| `BUFFER SORT` | Excessive memory sorting |
| High `Cost` / `Cardinality` mismatch | Stale statistics — run `DBMS_STATS.GATHER_TABLE_STATS` |

## Optimizer Hints

**WARNING:** Never use hints without benchmarking. Hints override the optimizer and can degrade performance as data changes.

| Hint | Purpose | Example |
|------|---------|---------|
| `/*+ INDEX(t idx_name) */` | Force specific index | Last resort for wrong index choice |
| `/*+ FULL(t) */` | Force full table scan | When index scan is slower (small tables) |
| `/*+ PARALLEL(t, 4) */` | Parallel execution | Batch/DW queries only |
| `/*+ NO_INDEX(t idx) */` | Prevent specific index | Testing alternative plans |
| `/*+ LEADING(t1 t2) */` | Join order | When optimizer picks wrong join order |
| `/*+ USE_HASH(t2) */` | Force hash join | Large set joins |

Prefer fixing root causes (statistics, indexes, query rewrite) over hints.

## Statistics Management

```sql
-- Gather stats for a table (run after bulk loads or schema changes)
EXEC DBMS_STATS.GATHER_TABLE_STATS('APP_SCHEMA', 'TRANSACTIONS', CASCADE => TRUE);

-- Gather stats for entire schema
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('APP_SCHEMA');

-- Check stale statistics
SELECT table_name, last_analyzed, stale_stats
FROM ALL_TAB_STATISTICS
WHERE owner = 'APP_SCHEMA' AND stale_stats = 'YES';
```

## Connection Pool — UCP / HikariCP

| Parameter | UCP (Oracle) | HikariCP | Recommended |
|-----------|-------------|----------|-------------|
| Min pool | `setMinPoolSize(5)` | `minimumIdle=5` | 5 |
| Max pool | `setMaxPoolSize(20)` | `maximumPoolSize=20` | 20 |
| Connection timeout | `setConnectionWaitDurationInMillis(5000)` | `connectionTimeout=5000` | 5s |
| Idle timeout | `setInactiveConnectionTimeout(300)` | `idleTimeout=300000` | 5 min |
| Validation | `setValidateConnectionOnBorrow(true)` | `SELECT 1 FROM DUAL` | On borrow |
| Statement cache | `setMaxStatements(50)` | N/A (driver-level) | 50 |

### Quarkus Configuration

```properties
quarkus.datasource.db-kind=oracle
quarkus.datasource.jdbc.url=jdbc:oracle:thin:@//host:1521/service_name
quarkus.datasource.jdbc.min-size=5
quarkus.datasource.jdbc.max-size=20
quarkus.datasource.jdbc.acquisition-timeout=5S
quarkus.datasource.jdbc.idle-removal-interval=5M
```

### Spring Boot Configuration

```yaml
spring:
  datasource:
    url: jdbc:oracle:thin:@//host:1521/service_name
    driver-class-name: oracle.jdbc.OracleDriver
    hikari:
      minimum-idle: 5
      maximum-pool-size: 20
      connection-timeout: 5000
      idle-timeout: 300000
      validation-timeout: 3000
      connection-test-query: SELECT 1 FROM DUAL
```

## Anti-Patterns

- Bitmap indexes on OLTP tables — severe row locking
- Hints without benchmarks — creates maintenance burden
- Stale statistics — run `GATHER_TABLE_STATS` after bulk operations
- `SELECT *` — list columns explicitly for covering index usage
- Missing partitioning on tables > 10M rows with date-range queries
- Ignoring `INVISIBLE` indexes for testing — safer than dropping
