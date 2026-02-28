---
name: django-patterns
description: "Django-specific patterns: ORM with QuerySet optimization, Class-Based Views, DRF serializers/viewsets, django-environ config, TestCase/APIClient testing, migrations, middleware. Internal reference for agents producing Django code."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Django Patterns

## Purpose

Provides Django-specific implementation patterns that supplement the generic layer templates. Agents reference this pack when generating code for a Python + Django project.

---

## 1. Django ORM

### Model Definition

```python
from django.db import models

class Merchant(models.Model):
    class Status(models.TextChoices):
        ACTIVE = "ACTIVE", "Active"
        INACTIVE = "INACTIVE", "Inactive"
        SUSPENDED = "SUSPENDED", "Suspended"

    mid = models.CharField(max_length=15, unique=True, db_index=True)
    name = models.CharField(max_length=100)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.ACTIVE)
    category = models.CharField(max_length=50, blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    objects = MerchantManager()

    class Meta:
        db_table = "merchants"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["status", "-created_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.mid} - {self.name}"

    def deactivate(self) -> None:
        self.status = self.Status.INACTIVE
        self.save(update_fields=["status", "updated_at"])
```

### Custom Manager

```python
from django.db import models


class MerchantQuerySet(models.QuerySet["Merchant"]):
    def active(self) -> "MerchantQuerySet":
        return self.filter(status=Merchant.Status.ACTIVE)

    def by_category(self, category: str) -> "MerchantQuerySet":
        return self.filter(category=category)

    def with_transaction_count(self) -> "MerchantQuerySet":
        return self.annotate(transaction_count=models.Count("transactions"))


class MerchantManager(models.Manager["Merchant"]):
    def get_queryset(self) -> MerchantQuerySet:
        return MerchantQuerySet(self.model, using=self._db)

    def active(self) -> MerchantQuerySet:
        return self.get_queryset().active()
```

### QuerySet Chaining

```python
# Chained filtering
merchants = (
    Merchant.objects
    .active()
    .by_category("RETAIL")
    .with_transaction_count()
    .order_by("-transaction_count")[:20]
)
```

### N+1 Prevention with select_related / prefetch_related

```python
# select_related — ForeignKey / OneToOne (SQL JOIN)
transactions = (
    Transaction.objects
    .select_related("merchant", "merchant__owner")
    .filter(status="PENDING")
)

# prefetch_related — ManyToMany / Reverse FK (separate query)
merchants = (
    Merchant.objects
    .prefetch_related("transactions", "tags")
    .active()
)

# Prefetch with custom queryset
from django.db.models import Prefetch

merchants = Merchant.objects.prefetch_related(
    Prefetch(
        "transactions",
        queryset=Transaction.objects.filter(status="APPROVED").order_by("-created_at")[:5],
        to_attr="recent_approved_transactions",
    )
)
```

### F() and Q() Expressions

```python
from django.db.models import F, Q

# F() — reference model fields in queries
Merchant.objects.filter(updated_at__gt=F("created_at"))

# Update without race condition
Account.objects.filter(id=account_id).update(balance=F("balance") - amount)

# Q() — complex lookups with OR / NOT
merchants = Merchant.objects.filter(
    Q(status="ACTIVE") | Q(status="SUSPENDED"),
    ~Q(category="BANNED"),
    name__icontains=search_term,
)
```

### annotate() / aggregate()

```python
from django.db.models import Count, Sum, Avg

# annotate — per-row computed field
merchants = Merchant.objects.annotate(
    total_transactions=Count("transactions"),
    total_volume=Sum("transactions__amount"),
).filter(total_transactions__gt=10)

# aggregate — single result across queryset
stats = Transaction.objects.filter(
    merchant_id=merchant_id,
    status="APPROVED",
).aggregate(
    total=Count("id"),
    volume=Sum("amount"),
    avg_amount=Avg("amount"),
)
# stats = {"total": 150, "volume": Decimal("45000.00"), "avg_amount": Decimal("300.00")}
```

---

## 2. Class-Based Views & DRF

### APIView

```python
from rest_framework import status
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView


class MerchantDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request: Request, merchant_id: int) -> Response:
        merchant = get_object_or_404(Merchant, pk=merchant_id)
        serializer = MerchantSerializer(merchant)
        return Response(serializer.data)

    def delete(self, request: Request, merchant_id: int) -> Response:
        merchant = get_object_or_404(Merchant, pk=merchant_id)
        merchant.deactivate()
        return Response(status=status.HTTP_204_NO_CONTENT)
```

### ModelViewSet

```python
from rest_framework import viewsets, filters
from rest_framework.decorators import action
from django_filters.rest_framework import DjangoFilterBackend


class MerchantViewSet(viewsets.ModelViewSet):
    queryset = Merchant.objects.all()
    serializer_class = MerchantSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = StandardPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_class = MerchantFilter
    search_fields = ["name", "mid"]
    ordering_fields = ["created_at", "name"]
    ordering = ["-created_at"]

    def get_queryset(self) -> models.QuerySet[Merchant]:
        return (
            Merchant.objects
            .select_related("owner")
            .prefetch_related("transactions")
            .active()
        )

    def get_serializer_class(self) -> type:
        if self.action == "create":
            return CreateMerchantSerializer
        return MerchantSerializer

    @action(detail=True, methods=["post"])
    def deactivate(self, request: Request, pk: int | None = None) -> Response:
        merchant = self.get_object()
        merchant.deactivate()
        return Response(status=status.HTTP_204_NO_CONTENT)
```

### GenericAPIView

```python
from rest_framework.generics import ListCreateAPIView, RetrieveUpdateDestroyAPIView


class MerchantListCreateView(ListCreateAPIView):
    queryset = Merchant.objects.active()
    serializer_class = MerchantSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = StandardPagination


class MerchantDetailView(RetrieveUpdateDestroyAPIView):
    queryset = Merchant.objects.all()
    serializer_class = MerchantSerializer
    permission_classes = [IsAuthenticated, IsOwnerOrReadOnly]
```

### Serializers

```python
from rest_framework import serializers


class MerchantSerializer(serializers.ModelSerializer):
    transaction_count = serializers.IntegerField(read_only=True, default=0)

    class Meta:
        model = Merchant
        fields = ["id", "mid", "name", "status", "category", "transaction_count", "created_at"]
        read_only_fields = ["id", "created_at"]


class CreateMerchantSerializer(serializers.ModelSerializer):
    class Meta:
        model = Merchant
        fields = ["mid", "name", "category"]

    def validate_mid(self, value: str) -> str:
        if Merchant.objects.filter(mid=value).exists():
            raise serializers.ValidationError(f"Merchant with MID '{value}' already exists.")
        return value
```

### Permission Classes

```python
from rest_framework.permissions import BasePermission


class IsOwnerOrReadOnly(BasePermission):
    def has_object_permission(self, request: Request, view: APIView, obj: Merchant) -> bool:
        if request.method in ("GET", "HEAD", "OPTIONS"):
            return True
        return obj.owner_id == request.user.id
```

### Pagination

```python
from rest_framework.pagination import PageNumberPagination


class StandardPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100
```

### Filtering with django-filter

```python
import django_filters


class MerchantFilter(django_filters.FilterSet):
    status = django_filters.ChoiceFilter(choices=Merchant.Status.choices)
    category = django_filters.CharFilter(lookup_expr="iexact")
    created_after = django_filters.DateTimeFilter(field_name="created_at", lookup_expr="gte")
    created_before = django_filters.DateTimeFilter(field_name="created_at", lookup_expr="lte")

    class Meta:
        model = Merchant
        fields = ["status", "category"]
```

---

## 3. Configuration

### django-environ for Env Vars

```python
# settings/base.py
import environ

env = environ.Env(
    DEBUG=(bool, False),
    ALLOWED_HOSTS=(list, []),
)

# Read .env file
environ.Env.read_env(BASE_DIR / ".env")

SECRET_KEY: str = env("SECRET_KEY")
DEBUG: bool = env("DEBUG")
ALLOWED_HOSTS: list[str] = env("ALLOWED_HOSTS")

DATABASES = {
    "default": env.db("DATABASE_URL"),
}

CACHES = {
    "default": env.cache("REDIS_URL", default="locmemcache://"),
}
```

### Split Settings (base / dev / prod)

```
settings/
  __init__.py
  base.py          # Shared settings
  development.py   # Local dev overrides
  production.py    # Production overrides
  test.py          # Test overrides
```

```python
# settings/development.py
from .base import *  # noqa: F401, F403

DEBUG = True
ALLOWED_HOSTS = ["localhost", "127.0.0.1"]

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": "merchants_dev",
        "HOST": "localhost",
        "PORT": "5432",
        "USER": "dev",
        "PASSWORD": "dev",
    }
}

# settings/production.py
from .base import *  # noqa: F401, F403

DEBUG = False
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True

LOGGING = {
    "version": 1,
    "handlers": {
        "console": {"class": "logging.StreamHandler", "formatter": "json"},
    },
    "formatters": {
        "json": {"()": "pythonjsonlogger.jsonlogger.JsonFormatter"},
    },
    "root": {"handlers": ["console"], "level": "INFO"},
}
```

### DJANGO_SETTINGS_MODULE

```bash
# Development
export DJANGO_SETTINGS_MODULE=config.settings.development

# Production
export DJANGO_SETTINGS_MODULE=config.settings.production

# Test
export DJANGO_SETTINGS_MODULE=config.settings.test
```

---

## 4. Testing

### TestCase with DRF APIClient

```python
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status


class MerchantAPITestCase(TestCase):
    def setUp(self) -> None:
        self.client = APIClient()
        self.user = User.objects.create_user(username="testuser", password="testpass")
        self.client.force_authenticate(user=self.user)
        self.merchant = Merchant.objects.create(mid="MID001", name="Test Merchant")

    def test_list_merchants(self) -> None:
        response = self.client.get("/api/v1/merchants/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 1)

    def test_create_merchant(self) -> None:
        data = {"mid": "MID002", "name": "New Merchant"}
        response = self.client.post("/api/v1/merchants/", data, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Merchant.objects.count(), 2)

    def test_create_merchant_duplicate_mid(self) -> None:
        data = {"mid": "MID001", "name": "Duplicate"}
        response = self.client.post("/api/v1/merchants/", data, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_get_merchant(self) -> None:
        response = self.client.get(f"/api/v1/merchants/{self.merchant.id}/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["mid"], "MID001")

    def test_delete_merchant(self) -> None:
        response = self.client.delete(f"/api/v1/merchants/{self.merchant.id}/")
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
```

### TransactionTestCase (When Transaction Isolation Matters)

```python
from django.test import TransactionTestCase


class MerchantTransactionTestCase(TransactionTestCase):
    def test_concurrent_balance_update(self) -> None:
        account = Account.objects.create(balance=100)
        Account.objects.filter(id=account.id).update(balance=F("balance") - 50)
        account.refresh_from_db()
        self.assertEqual(account.balance, 50)
```

### factory_boy for Fixtures

```python
import factory
from factory.django import DjangoModelFactory


class MerchantFactory(DjangoModelFactory):
    class Meta:
        model = Merchant

    mid = factory.Sequence(lambda n: f"MID{n:04d}")
    name = factory.Faker("company")
    status = Merchant.Status.ACTIVE
    category = "RETAIL"


class TransactionFactory(DjangoModelFactory):
    class Meta:
        model = Transaction

    merchant = factory.SubFactory(MerchantFactory)
    amount = factory.Faker("pydecimal", left_digits=4, right_digits=2, positive=True)
    status = "APPROVED"
```

### pytest-django

```python
import pytest
from rest_framework.test import APIClient


@pytest.fixture
def api_client(db: None) -> APIClient:
    user = User.objects.create_user(username="testuser", password="testpass")
    client = APIClient()
    client.force_authenticate(user=user)
    return client


@pytest.fixture
def merchant(db: None) -> Merchant:
    return MerchantFactory()


@pytest.mark.django_db
def test_list_merchants(api_client: APIClient, merchant: Merchant) -> None:
    response = api_client.get("/api/v1/merchants/")
    assert response.status_code == 200
    assert len(response.data["results"]) == 1


@pytest.mark.django_db
def test_create_merchant(api_client: APIClient) -> None:
    data = {"mid": "MID001", "name": "New Merchant"}
    response = api_client.post("/api/v1/merchants/", data, format="json")
    assert response.status_code == 201
    assert Merchant.objects.count() == 1
```

### Mock with unittest.mock

```python
from unittest.mock import patch, MagicMock


@pytest.mark.django_db
def test_merchant_notification(api_client: APIClient) -> None:
    with patch("merchants.services.NotificationService.send") as mock_send:
        mock_send.return_value = None
        data = {"mid": "MID001", "name": "Test"}
        response = api_client.post("/api/v1/merchants/", data, format="json")
        assert response.status_code == 201
        mock_send.assert_called_once()
```

---

## 5. Migrations

### Basic Commands

```bash
# Detect model changes and create migration
python manage.py makemigrations merchants

# Apply all pending migrations
python manage.py migrate

# Show migration status
python manage.py showmigrations

# Generate SQL without applying
python manage.py sqlmigrate merchants 0001
```

### Data Migration with RunPython

```python
from django.db import migrations


def populate_default_categories(apps, schema_editor):
    Merchant = apps.get_model("merchants", "Merchant")
    Merchant.objects.filter(category="").update(category="GENERAL")


def reverse_populate(apps, schema_editor):
    Merchant = apps.get_model("merchants", "Merchant")
    Merchant.objects.filter(category="GENERAL").update(category="")


class Migration(migrations.Migration):
    dependencies = [
        ("merchants", "0003_add_category_field"),
    ]

    operations = [
        migrations.RunPython(populate_default_categories, reverse_populate),
    ]
```

### Squashing Migrations

```bash
# Squash migrations 0001 through 0010 into one
python manage.py squashmigrations merchants 0001 0010
```

### Reversible Migrations

```python
class Migration(migrations.Migration):
    dependencies = [
        ("merchants", "0004_data_migration"),
    ]

    operations = [
        migrations.AddField(
            model_name="merchant",
            name="email",
            field=models.EmailField(max_length=254, blank=True, default=""),
        ),
        migrations.AddIndex(
            model_name="merchant",
            index=models.Index(fields=["email"], name="idx_merchant_email"),
        ),
    ]
```

---

## 6. Middleware

### Custom Middleware Class

```python
from django.http import HttpRequest, HttpResponse
from django.utils.deprecation import MiddlewareMixin


class RequestTimingMiddleware(MiddlewareMixin):
    def process_request(self, request: HttpRequest) -> None:
        request._start_time = time.monotonic()

    def process_response(self, request: HttpRequest, response: HttpResponse) -> HttpResponse:
        if hasattr(request, "_start_time"):
            elapsed = time.monotonic() - request._start_time
            response["X-Request-Duration-Ms"] = f"{elapsed * 1000:.2f}"
            logger.info(
                "Request completed",
                extra={
                    "method": request.method,
                    "path": request.path,
                    "status": response.status_code,
                    "duration_ms": f"{elapsed * 1000:.2f}",
                },
            )
        return response
```

### ASGI Middleware (Django 4.2+)

```python
from django.http import HttpRequest, HttpResponse


class TenantMiddleware:
    def __init__(self, get_response) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        tenant_id = request.headers.get("X-Tenant-ID")
        if tenant_id:
            request.tenant_id = tenant_id
        response = self.get_response(request)
        return response

    async def __acall__(self, request: HttpRequest) -> HttpResponse:
        tenant_id = request.headers.get("X-Tenant-ID")
        if tenant_id:
            request.tenant_id = tenant_id
        response = await self.get_response(request)
        return response
```

### Built-In Middleware Order

```python
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",           # 1. Security headers
    "django.contrib.sessions.middleware.SessionMiddleware",    # 2. Session handling
    "corsheaders.middleware.CorsMiddleware",                   # 3. CORS (before CommonMiddleware)
    "django.middleware.common.CommonMiddleware",               # 4. URL normalization
    "django.middleware.csrf.CsrfViewMiddleware",              # 5. CSRF protection
    "django.contrib.auth.middleware.AuthenticationMiddleware", # 6. Auth
    "django.contrib.messages.middleware.MessageMiddleware",    # 7. Messages
    "django.middleware.clickjacking.XFrameOptionsMiddleware",  # 8. Clickjacking protection
    "app.middleware.RequestTimingMiddleware",                  # 9. Custom (last)
]
```

---

## Anti-Patterns (Django-Specific)

- Fat views with business logic (extract to service layer or model methods)
- N+1 queries in templates or serializers (always use `select_related` / `prefetch_related`)
- Missing `select_related` / `prefetch_related` on related field access
- Raw SQL in views or serializers (use ORM QuerySet API, reserve raw SQL for repositories)
- Using signals for business logic (signals are implicit; use explicit service calls)
- `objects.all()` without pagination (unbounded queries on large tables)
- `Model.objects.get()` without handling `DoesNotExist` (use `get_object_or_404` or `filter().first()`)
- Mutable default arguments in model methods or service functions
- Missing `update_fields` in `save()` calls (updates all columns unnecessarily)
- Database queries in `__str__` or `__repr__` methods (triggers N+1 in admin/logging)
- Using `@receiver` signals instead of explicit service method calls for critical workflows
