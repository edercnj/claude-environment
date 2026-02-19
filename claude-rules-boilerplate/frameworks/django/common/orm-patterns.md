# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Django — ORM Patterns
> Extends: `core/11-database-principles.md`

## Model Definition

```python
from django.db import models

class Merchant(models.Model):
    mid = models.CharField(max_length=15, unique=True, db_index=True)
    name = models.CharField(max_length=100)
    document = models.CharField(max_length=14)
    mcc = models.CharField(max_length=4)
    status = models.CharField(max_length=20, default="ACTIVE", db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "merchants"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["mid"], name="idx_merchants_mid"),
            models.Index(fields=["status", "-created_at"], name="idx_merchants_status_date"),
        ]

    def __str__(self) -> str:
        return f"Merchant({self.mid})"

class Terminal(models.Model):
    tid = models.CharField(max_length=8, unique=True, db_index=True)
    merchant = models.ForeignKey(Merchant, on_delete=models.CASCADE, related_name="terminals")
    model_name = models.CharField(max_length=50)
    serial_number = models.CharField(max_length=50)
    status = models.CharField(max_length=20, default="ACTIVE")
    force_timeout = models.BooleanField(default=False)
    timeout_seconds = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "terminals"
```

## Custom Managers

```python
class ActiveManager(models.Manager):
    def get_queryset(self) -> models.QuerySet:
        return super().get_queryset().filter(status="ACTIVE")

class Merchant(models.Model):
    # ... fields ...
    objects = models.Manager()
    active = ActiveManager()
```

## QuerySet Patterns

```python
# Efficient queries
merchants = Merchant.active.select_related().filter(mcc="5411")[:20]

# Prefetch for N+1 prevention
merchants = Merchant.active.prefetch_related("terminals").all()

# Aggregation
from django.db.models import Count, Avg
stats = Merchant.objects.aggregate(total=Count("id"), avg_terminals=Avg("terminals__id"))

# Bulk operations
Merchant.objects.filter(status="INACTIVE").update(status="DELETED")
```

## Migrations

```bash
# Create migration
python manage.py makemigrations merchants

# Apply
python manage.py migrate

# Show SQL without applying
python manage.py sqlmigrate merchants 0001
```

## Data Types

| Data              | Django Field         | DB Type              |
| ----------------- | -------------------- | -------------------- |
| ID                | AutoField / BigAutoField | BIGSERIAL         |
| Money (cents)     | BigIntegerField      | BIGINT               |
| Timestamps        | DateTimeField        | TIMESTAMP WITH TZ    |
| Short strings     | CharField(max)       | VARCHAR(N)           |
| Long text         | TextField            | TEXT                 |
| Boolean flags     | BooleanField         | BOOLEAN              |
| JSON data         | JSONField            | JSONB (PostgreSQL)   |

## Anti-Patterns

- Do NOT use `objects.all()` without pagination in views -- always limit results
- Do NOT use `.get()` without handling `DoesNotExist` -- use `.filter().first()` or try/except
- Do NOT ignore `select_related` / `prefetch_related` -- prevent N+1 queries
- Do NOT use `FLOAT` for monetary values -- use `BigIntegerField` (cents)
- Do NOT modify migrations already applied in production -- create new ones
