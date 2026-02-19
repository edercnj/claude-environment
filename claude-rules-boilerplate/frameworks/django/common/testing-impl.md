# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Django — Testing Patterns

## pytest-django Setup

```ini
# pytest.ini
[pytest]
DJANGO_SETTINGS_MODULE = config.settings.test
python_files = tests.py test_*.py *_tests.py
```

## API Tests with APIClient

```python
import pytest
from rest_framework.test import APIClient
from rest_framework import status

@pytest.fixture
def api_client() -> APIClient:
    client = APIClient()
    client.credentials(HTTP_X_API_KEY="test-key-1234567890")
    return client

@pytest.mark.django_db
def test_create_merchant(api_client: APIClient):
    response = api_client.post("/api/v1/merchants/", {
        "mid": "123456789012345", "name": "Test Store", "document": "12345678000190", "mcc": "5411",
    }, format="json")

    assert response.status_code == status.HTTP_201_CREATED
    assert response.data["mid"] == "123456789012345"

@pytest.mark.django_db
def test_get_merchant_not_found(api_client: APIClient):
    response = api_client.get("/api/v1/merchants/99999/")
    assert response.status_code == status.HTTP_404_NOT_FOUND

@pytest.mark.django_db
def test_create_duplicate_merchant(api_client: APIClient, merchant_factory):
    existing = merchant_factory(mid="DUPLICATE123456")
    response = api_client.post("/api/v1/merchants/", {
        "mid": "DUPLICATE123456", "name": "Other", "document": "12345678000190", "mcc": "5411",
    }, format="json")
    assert response.status_code == status.HTTP_409_CONFLICT
```

## factory_boy Fixtures

```python
import factory
from merchants.models import Merchant, Terminal

class MerchantFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Merchant

    mid = factory.Sequence(lambda n: f"MID{n:011d}")
    name = factory.Faker("company")
    document = "12345678000190"
    mcc = "5411"
    status = "ACTIVE"

class TerminalFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Terminal

    tid = factory.Sequence(lambda n: f"T{n:07d}")
    merchant = factory.SubFactory(MerchantFactory)
    model_name = "PAX-A920"
    serial_number = factory.Faker("uuid4")

@pytest.fixture
def merchant_factory(db):
    return MerchantFactory
```

## Model Tests

```python
@pytest.mark.django_db
def test_merchant_str():
    merchant = MerchantFactory(mid="123456789012345")
    assert str(merchant) == "Merchant(123456789012345)"

@pytest.mark.django_db
def test_active_manager_excludes_deleted():
    MerchantFactory(status="ACTIVE")
    MerchantFactory(status="DELETED")
    assert Merchant.active.count() == 1
```

## Naming Convention

```
test_[component]_[scenario]_[expected]
```

Examples: `test_create_merchant_valid_returns_201`, `test_active_manager_excludes_deleted`

## Anti-Patterns

- Do NOT forget `@pytest.mark.django_db` on tests that access the database
- Do NOT use fixed IDs in factories -- use `factory.Sequence`
- Do NOT test Django internals -- test your views, serializers, and models
- Do NOT share state between tests -- each test gets a fresh transaction
- Do NOT skip error path testing -- validate 400, 404, 409 responses
