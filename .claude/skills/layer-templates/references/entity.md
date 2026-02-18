# Template: JPA Entity

## Pattern

```java
package com.bifrost.simulator.adapter.outbound.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;

@Entity
@Table(name = "merchants", schema = "simulator")
public class MerchantEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "mid", nullable = false, unique = true, length = 15)
    private String mid;

    @Column(name = "legal_name", nullable = false, length = 100)
    private String legalName;

    @Column(name = "trade_name", nullable = false, length = 100)
    private String tradeName;

    @Column(name = "document", nullable = false, length = 14)
    private String document;

    @Column(name = "mcc", nullable = false, length = 4)
    private String mcc;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private String status;

    @Column(name = "force_timeout", nullable = false)
    private boolean forceTimeout;

    @Column(name = "timeout_seconds")
    private Integer timeoutSeconds;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    // Getters and setters (Panache requires them)

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getMid() { return mid; }
    public void setMid(String mid) { this.mid = mid; }

    public String getLegalName() { return legalName; }
    public void setLegalName(String legalName) { this.legalName = legalName; }

    public String getTradeName() { return tradeName; }
    public void setTradeName(String tradeName) { this.tradeName = tradeName; }

    public String getDocument() { return document; }
    public void setDocument(String document) { this.document = document; }

    public String getMcc() { return mcc; }
    public void setMcc(String mcc) { this.mcc = mcc; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public boolean isForceTimeout() { return forceTimeout; }
    public void setForceTimeout(boolean forceTimeout) { this.forceTimeout = forceTimeout; }

    public Integer getTimeoutSeconds() { return timeoutSeconds; }
    public void setTimeoutSeconds(Integer timeoutSeconds) { this.timeoutSeconds = timeoutSeconds; }

    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }

    public OffsetDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(OffsetDateTime updatedAt) { this.updatedAt = updatedAt; }
}
```

## CHANGE THESE

- **Class name**: `{Entity}Entity`
- **@Table name**: Plural, snake_case (e.g., `merchants`, `transactions`, `terminals`)
- **Columns**: Match the Flyway migration DDL exactly
- **Types**: `BIGINT` -> `Long`, `VARCHAR` -> `String`, `TIMESTAMPTZ` -> `OffsetDateTime`, `BOOLEAN` -> `boolean`

## Critical Rules (memorize)

1. Schema is ALWAYS `simulator` (`@Table(schema = "simulator")`)
2. `BIGSERIAL` -> `@GeneratedValue(strategy = GenerationType.IDENTITY)`
3. `created_at` is `updatable = false`
4. NEVER store full PAN — only masked
5. NO `@RegisterForReflection` needed (Hibernate/Panache registers automatically)

## Checklist

- [ ] `@Entity` and `@Table(name, schema = "simulator")`
- [ ] `@Id` + `@GeneratedValue(strategy = IDENTITY)`
- [ ] `created_at` with `updatable = false`
- [ ] `updated_at` present
- [ ] Column names match migration DDL (snake_case)
- [ ] Getters and setters for all fields
- [ ] No `@RegisterForReflection`
- [ ] Class <= 250 lines
