---
name: database-patterns
description: "PostgreSQL and Flyway conventions: migration naming, schema design, Panache repository patterns, index strategies, data types. Referenced internally by agents needing database context."
user-invocable: false
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Database Management (PostgreSQL + Flyway)

## Description

Guide for working with PostgreSQL and Flyway in the ISO 8583 authorizer simulator.

## Flyway Migrations

### Naming Convention

```
V{version}__{description}.sql
```

Examples:

- `V1__create_schema.sql`
- `V2__create_transaction_table.sql`
- `V3__create_merchant_terminal_tables.sql`
- `V4__create_iso_log_table.sql`
- `V5__add_reversal_status_column.sql`

### Location

`src/main/resources/db/migration/`

### Migration Template

```sql
-- V{N}__{description}.sql
-- Description: [what this migration does]
-- Story: STORY-NNN

BEGIN;

CREATE TABLE IF NOT EXISTS simulator.table_name (
    id BIGSERIAL PRIMARY KEY,
    -- columns
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_table_column ON simulator.table_name (column);

COMMIT;
```

### Important Rules

- **NEVER** alter a migration already applied in production — create a new migration
- **ALWAYS** use explicit transactions (`BEGIN; ... COMMIT;`)
- **ALWAYS** use `IF NOT EXISTS` for idempotency
- **ALWAYS** include `created_at` and `updated_at` in tables
- **ALWAYS** comment which story created the migration

## Expected Schema

### Default Schema

All tables in the `simulator` schema:

```sql
CREATE SCHEMA IF NOT EXISTS simulator;
```

### Expected Tables

#### transactions

```sql
CREATE TABLE simulator.transactions (
    id BIGSERIAL PRIMARY KEY,
    mti VARCHAR(4) NOT NULL,
    processing_code VARCHAR(6),
    amount BIGINT,                    -- in cents
    stan VARCHAR(6) NOT NULL,
    local_date_time VARCHAR(12),
    pan_masked VARCHAR(19),           -- first 6 + last 4
    response_code VARCHAR(2),
    authorization_code VARCHAR(6),
    rrn VARCHAR(12),
    merchant_id VARCHAR(15),
    terminal_id VARCHAR(8),
    mcc VARCHAR(4),
    account_type VARCHAR(2),
    original_mti VARCHAR(4),          -- for reversals
    original_stan VARCHAR(6),         -- for reversals
    status VARCHAR(20) NOT NULL DEFAULT 'PROCESSED',
    raw_request BYTEA,
    raw_response BYTEA,
    processing_time_ms INTEGER,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_transactions_stan ON simulator.transactions(stan);
CREATE INDEX idx_transactions_merchant_id ON simulator.transactions(merchant_id);
CREATE INDEX idx_transactions_terminal_id ON simulator.transactions(terminal_id);
CREATE INDEX idx_transactions_response_code ON simulator.transactions(response_code);
CREATE INDEX idx_transactions_status ON simulator.transactions(status);
CREATE INDEX idx_transactions_created_at ON simulator.transactions(created_at);
```

#### merchants

```sql
CREATE TABLE simulator.merchants (
    id BIGSERIAL PRIMARY KEY,
    mid VARCHAR(15) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    document VARCHAR(14) NOT NULL,    -- CNPJ or CPF
    mcc VARCHAR(4) NOT NULL,
    timeout_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_merchants_mid ON simulator.merchants(mid);
CREATE INDEX idx_merchants_status ON simulator.merchants(status);
```

#### terminals

```sql
CREATE TABLE simulator.terminals (
    id BIGSERIAL PRIMARY KEY,
    tid VARCHAR(8) NOT NULL UNIQUE,
    merchant_id BIGINT NOT NULL REFERENCES simulator.merchants(id) ON DELETE CASCADE,
    model VARCHAR(50),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_terminals_tid ON simulator.terminals(tid);
CREATE INDEX idx_terminals_merchant_id ON simulator.terminals(merchant_id);
CREATE INDEX idx_terminals_status ON simulator.terminals(status);
```

#### iso_logs

```sql
CREATE TABLE simulator.iso_logs (
    id BIGSERIAL PRIMARY KEY,
    direction VARCHAR(10) NOT NULL,   -- REQUEST, RESPONSE
    mti VARCHAR(4) NOT NULL,
    raw_hex TEXT NOT NULL,
    parsed_fields JSONB,
    source_ip VARCHAR(45),
    transaction_id BIGINT REFERENCES simulator.transactions(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_iso_logs_direction ON simulator.iso_logs(direction);
CREATE INDEX idx_iso_logs_mti ON simulator.iso_logs(mti);
CREATE INDEX idx_iso_logs_transaction_id ON simulator.iso_logs(transaction_id);
CREATE INDEX idx_iso_logs_created_at ON simulator.iso_logs(created_at);
```

## Panache Repository Pattern

### Example: TransactionRepository

```java
package com.bifrost.simulator.adapter.outbound.persistence.repository;

import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import com.bifrost.simulator.adapter.outbound.persistence.entity.TransactionEntity;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

@ApplicationScoped
public class TransactionRepository implements PanacheRepository<TransactionEntity> {

    public Optional<TransactionEntity> findByStanAndDate(String stan, String dateTime) {
        return find("stan = ?1 and localDateTime = ?2", stan, dateTime)
                .firstResultOptional();
    }

    public List<TransactionEntity> findByMerchantId(String mid) {
        return find("merchantId", mid).list();
    }

    public long countByResponseCode(String rc) {
        return count("responseCode", rc);
    }

    public List<TransactionEntity> findByStatus(String status) {
        return find("status", status).list();
    }

    public void deleteOlderThan(OffsetDateTime cutoff) {
        delete("createdAt < ?1", cutoff);
    }
}
```

### Common Operations

```java
// Create
transactionRepository.persist(entity);

// Read
Optional<TransactionEntity> entity = transactionRepository.findByIdOptional(id);

// Update
entity.setStatus("REVERSED");
transactionRepository.update(entity);

// Delete
transactionRepository.deleteById(id);

// Query
List<TransactionEntity> entities = transactionRepository.find("merchantId = ?1", mid).list();

// Count
long count = transactionRepository.count("responseCode = ?1", "00");

// Pagination
List<TransactionEntity> page = transactionRepository.find("status", "PROCESSED")
    .page(0, 10)
    .list();

// Sorting
List<TransactionEntity> sorted = transactionRepository.find("status", "PROCESSED")
    .sort("createdAt", Sort.Direction.Descending)
    .list();
```

## JPA Entity Pattern

### Example: TransactionEntity

```java
package com.bifrost.simulator.adapter.outbound.persistence.entity;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "transactions", schema = "simulator")
public class TransactionEntity extends PanacheEntity {

    @Column(name = "mti", nullable = false, length = 4)
    public String mti;

    @Column(name = "processing_code", length = 6)
    public String processingCode;

    @Column(name = "amount")
    public Long amount;  // in cents

    @Column(name = "stan", nullable = false, length = 6)
    public String stan;

    @Column(name = "local_date_time", length = 12)
    public String localDateTime;

    @Column(name = "pan_masked", length = 19)
    public String panMasked;

    @Column(name = "response_code", length = 2)
    public String responseCode;

    @Column(name = "authorization_code", length = 6)
    public String authorizationCode;

    @Column(name = "rrn", length = 12)
    public String rrn;

    @Column(name = "merchant_id", length = 15)
    public String merchantId;

    @Column(name = "terminal_id", length = 8)
    public String terminalId;

    @Column(name = "mcc", length = 4)
    public String mcc;

    @Column(name = "status", nullable = false, length = 20)
    public String status = "PROCESSED";

    @Column(name = "raw_request")
    public byte[] rawRequest;

    @Column(name = "raw_response")
    public byte[] rawResponse;

    @Column(name = "processing_time_ms")
    public Integer processingTimeMs;

    @Column(name = "created_at", nullable = false, updatable = false)
    public OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    public OffsetDateTime updatedAt;

    @PrePersist
    void prePersist() {
        createdAt = OffsetDateTime.now();
        updatedAt = OffsetDateTime.now();
    }

    @PreUpdate
    void preUpdate() {
        updatedAt = OffsetDateTime.now();
    }
}
```

## Connection Pool

Configured in `application.properties`:

```properties
quarkus.datasource.jdbc.min-size=5
quarkus.datasource.jdbc.max-size=20
quarkus.datasource.jdbc.acquisition-timeout=5S
```

### Explanation

- **min-size:** Keeps 5 connections always open (warm)
- **max-size:** Maximum of 20 simultaneous connections
- **acquisition-timeout:** Waits 5 seconds for an available connection

## Backup Strategy

### Manual Backup

```bash
# Full backup
pg_dump -h localhost -U simulator -d simulator > backup-$(date +%Y%m%d-%H%M%S).sql

# Restore
psql -h localhost -U simulator -d simulator < backup-20260216-143000.sql
```

### Production Backup (K8S)

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
spec:
  schedule: "0 2 * * *" # 2 AM daily
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: postgres:16
              command:
                - /bin/bash
                - -c
                - |
                  pg_dump -h postgresql -U simulator simulator | gzip > /backups/backup-$(date +%Y%m%d-%H%M%S).sql.gz
                  find /backups -name "backup-*.sql.gz" -mtime +7 -delete
              volumeMounts:
                - name: backup-storage
                  mountPath: /backups
          volumes:
            - name: backup-storage
              persistentVolumeClaim:
                claimName: backup-pvc
          restartPolicy: OnFailure
```

## Troubleshooting

### Flyway Migration Fails

```bash
# View migration history
psql -h localhost -U simulator -d simulator -c "SELECT * FROM flyway_schema_history ORDER BY success, installed_rank DESC;"

# Repair (dev/test only)
mvn flyway:repair

# Clean and recreate (dev/test only, DANGEROUS!)
mvn flyway:clean
mvn flyway:migrate
```

### Inefficient Indexes

```bash
# Analyze unused indexes
psql -h localhost -U simulator -d simulator -c "
SELECT schemaname, tablename, indexname
FROM pg_indexes
WHERE schemaname = 'simulator'
ORDER BY tablename, indexname;
"

# View table bloat
psql -h localhost -U simulator -d simulator -c "
SELECT schemaname, tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'simulator'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
"
```

### Deadlocks

Configure transaction timeout:

```properties
quarkus.hibernate-orm.jdbc.statement-timeout=30
```

### Connection Refused

```bash
# Check if PostgreSQL is running
docker ps | grep postgres

# If not, start it
docker run --name postgres -e POSTGRES_PASSWORD=simulator -e POSTGRES_DB=simulator -p 5432:5432 postgres:16
```
