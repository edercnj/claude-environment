# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Python Testing Conventions

## Framework

- **pytest** as test framework (NEVER `unittest` directly)
- **pytest-cov** for coverage reporting
- **pytest-asyncio** for async test support

## Coverage Thresholds

| Metric          | Minimum |
| --------------- | ------- |
| Line Coverage   | >= 95%  |
| Branch Coverage | >= 90%  |

## Naming Convention

```
test_{function}_{scenario}_{expected}
```

```python
def test_find_merchant_existing_mid_returns_merchant():
    ...

def test_find_merchant_nonexistent_mid_returns_none():
    ...

def test_create_merchant_duplicate_mid_raises_already_exists():
    ...
```

## Test Structure (Arrange-Act-Assert)

```python
def test_create_merchant_valid_payload_returns_merchant():
    # Arrange
    request = CreateMerchantRequest(
        mid="MID000000000001",
        name="Test Store",
        document="12345678000190",
        mcc="5411",
    )
    service = MerchantService(repository=InMemoryMerchantRepository())

    # Act
    result = service.create_merchant(request)

    # Assert
    assert result.mid == "MID000000000001"
    assert result.status == MerchantStatus.ACTIVE
```

## Fixtures

```python
import pytest
from app.domain.models import Merchant, MerchantStatus

@pytest.fixture
def merchant_repository():
    return InMemoryMerchantRepository()

@pytest.fixture
def merchant_service(merchant_repository):
    return MerchantService(repository=merchant_repository)

@pytest.fixture
def sample_merchant() -> Merchant:
    return Merchant(
        id=1,
        mid="MID000000000001",
        name="Test Store",
        document="12345678000190",
        mcc="5411",
        status=MerchantStatus.ACTIVE,
    )
```

### Factory Fixtures

```python
@pytest.fixture
def create_merchant():
    def _create(
        mid: str = "MID000000000001",
        name: str = "Test Store",
        status: MerchantStatus = MerchantStatus.ACTIVE,
        **kwargs,
    ) -> Merchant:
        return Merchant(
            id=kwargs.get("id", 1),
            mid=mid,
            name=name,
            document=kwargs.get("document", "12345678000190"),
            mcc=kwargs.get("mcc", "5411"),
            status=status,
        )
    return _create

def test_deactivate_merchant(create_merchant, merchant_service):
    merchant = create_merchant(status=MerchantStatus.ACTIVE)
    result = merchant_service.deactivate(merchant)
    assert result.status == MerchantStatus.INACTIVE
```

## Parametrized Tests

```python
@pytest.mark.parametrize(
    "amount, expected_rc, description",
    [
        ("100.00", "00", "approved"),
        ("100.51", "51", "insufficient_funds"),
        ("100.05", "05", "generic_error"),
        ("100.14", "14", "invalid_card"),
        ("100.43", "43", "stolen_card"),
    ],
)
def test_cents_rule_various_amounts_correct_response_code(
    amount: str, expected_rc: str, description: str
):
    engine = CentsDecisionEngine()
    result = engine.decide(Decimal(amount))
    assert result.response_code == expected_rc
```

## API Testing

```python
import pytest
from httpx import AsyncClient
from app.main import app

@pytest.fixture
async def client():
    async with AsyncClient(app=app, base_url="http://test") as client:
        yield client

@pytest.mark.asyncio
async def test_create_merchant_valid_payload_returns_201(client: AsyncClient):
    response = await client.post(
        "/api/v1/merchants",
        json={
            "mid": "MID000000000001",
            "name": "Test Store",
            "document": "12345678000190",
            "mcc": "5411",
        },
    )
    assert response.status_code == 201
    assert response.json()["mid"] == "MID000000000001"

@pytest.mark.asyncio
async def test_create_merchant_invalid_payload_returns_422(client: AsyncClient):
    response = await client.post(
        "/api/v1/merchants",
        json={"mid": ""},
    )
    assert response.status_code == 422
```

## Mocking

```python
from unittest.mock import AsyncMock, MagicMock, patch

def test_process_order_calls_payment_gateway(merchant_service):
    gateway = MagicMock()
    gateway.charge.return_value = PaymentResult(success=True)

    service = OrderService(payment_gateway=gateway)
    service.process(order)

    gateway.charge.assert_called_once_with(order.amount, order.currency)

# pytest-mock
def test_send_notification(mocker):
    mock_send = mocker.patch("app.services.notification.send_email")
    service.notify_merchant(merchant)
    mock_send.assert_called_once()
```

## Directory Structure

```
tests/
├── conftest.py              # Shared fixtures
├── domain/
│   ├── test_merchant.py
│   └── test_order.py
├── services/
│   └── test_merchant_service.py
├── repositories/
│   └── test_merchant_repository.py
├── api/
│   └── test_merchant_endpoints.py
└── fixtures/
    ├── merchant_fixtures.py
    └── order_fixtures.py
```

## Anti-Patterns

- Using `unittest.TestCase` directly (use pytest functions)
- `assert True` or `assert False` without context
- Tests depending on execution order
- Shared mutable state between tests
- Mocking domain/business logic
- `time.sleep()` in tests (use `pytest-timeout` or mock time)
- Tests without assertions
