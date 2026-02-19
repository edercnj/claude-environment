# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# FastAPI — Testing Patterns

## TestClient (Synchronous)

```python
from fastapi.testclient import TestClient

client = TestClient(app)

def test_create_merchant():
    response = client.post(
        "/api/v1/merchants",
        json={"mid": "123456789012345", "name": "Test", "document": "12345678000190", "mcc": "5411"},
        headers={"X-API-Key": "test-key-1234567890"},
    )
    assert response.status_code == 201
    assert response.json()["mid"] == "123456789012345"

def test_get_merchant_not_found():
    response = client.get("/api/v1/merchants/99999", headers={"X-API-Key": "test-key-1234567890"})
    assert response.status_code == 404
    assert response.json()["type"] == "/errors/not-found"
```

## Async Tests with httpx

```python
import pytest
from httpx import AsyncClient, ASGITransport

@pytest.fixture
async def async_client() -> AsyncGenerator[AsyncClient, None]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client

@pytest.mark.anyio
async def test_list_merchants(async_client: AsyncClient):
    response = await async_client.get("/api/v1/merchants", headers={"X-API-Key": "test-key"})
    assert response.status_code == 200
    assert "data" in response.json()
```

## Dependency Overrides

```python
@pytest.fixture(autouse=True)
def override_dependencies():
    async def mock_db():
        async with test_session_maker() as session:
            yield session

    app.dependency_overrides[get_db] = mock_db
    app.dependency_overrides[get_settings] = lambda: Settings(
        database_url="sqlite+aiosqlite:///test.db", api_key="test-key-1234567890"
    )
    yield
    app.dependency_overrides.clear()
```

## Fixtures with conftest.py

```python
@pytest.fixture
def merchant_data() -> dict:
    return {"mid": f"MID{int(time.time_ns()) % 1_000_000_000}", "name": "Test Store", "document": "12345678000190", "mcc": "5411"}

@pytest.fixture
async def created_merchant(async_client: AsyncClient, merchant_data: dict) -> dict:
    response = await async_client.post("/api/v1/merchants", json=merchant_data, headers={"X-API-Key": "test-key"})
    return response.json()
```

## Unit Tests for Services

```python
@pytest.mark.anyio
async def test_service_find_by_mid():
    repo = AsyncMock(spec=MerchantRepository)
    repo.find_by_mid.return_value = MerchantEntity(id=1, mid="123", name="Store")
    service = MerchantService(repo)

    result = await service.find_by_mid("123")

    assert result.mid == "123"
    repo.find_by_mid.assert_called_once_with("123")

@pytest.mark.anyio
async def test_service_find_by_mid_not_found():
    repo = AsyncMock(spec=MerchantRepository)
    repo.find_by_mid.return_value = None
    service = MerchantService(repo)

    with pytest.raises(AppException, match="not found"):
        await service.find_by_mid("unknown")
```

## Naming Convention

```
test_[unit]_[scenario]_[expected]
```

Examples: `test_create_merchant_valid_returns_201`, `test_find_by_mid_unknown_raises_404`

## Anti-Patterns

- Do NOT use real databases in unit tests -- mock repositories
- Do NOT forget `dependency_overrides.clear()` after tests
- Do NOT skip validation error tests -- verify 422 responses
- Do NOT use synchronous TestClient for async-only dependencies -- use httpx AsyncClient
