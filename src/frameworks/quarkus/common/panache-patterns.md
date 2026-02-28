# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Quarkus — Panache Repository Pattern

> Data access patterns using Hibernate ORM with Panache.

## Repository Pattern

```java
@ApplicationScoped
public class MerchantRepository implements PanacheRepository<MerchantEntity> {

    public Optional<MerchantEntity> findByMid(String mid) {
        return find("mid", mid).firstResultOptional();
    }

    public List<MerchantEntity> listPaged(int page, int limit) {
        return findAll(Sort.by("createdAt").descending())
            .page(Page.of(page, limit))
            .list();
    }

    public long countAll() {
        return count();
    }
}
```

## Entity Mapper Pattern

Location: `adapter.outbound.persistence.mapper`

```java
public final class TransactionEntityMapper {

    private TransactionEntityMapper() {}

    public static TransactionEntity toEntity(Transaction transaction) {
        var entity = new TransactionEntity();
        entity.setMti(transaction.mti());
        entity.setStan(transaction.stan());
        entity.setResponseCode(transaction.responseCode());
        entity.setAmountCents(transaction.amountCents());
        return entity;
    }

    public static Transaction toDomain(TransactionEntity entity) {
        return new Transaction(
            entity.getId(), entity.getMti(), entity.getStan(),
            entity.getResponseCode(), entity.getAmountCents(),
            entity.getCreatedAt()
        );
    }
}
```

**Rules:**
- `final class` + `private` constructor + `static` methods
- NOT a CDI bean — not needed
- WITHOUT `@RegisterForReflection` — not serialized by Jackson
- NEVER expose JPA Entities outside the persistence adapter
