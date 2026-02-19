# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# FastAPI — Dependency Injection Patterns

## Depends() Function

FastAPI uses `Depends()` for dependency injection at the route level:

```python
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_maker() as session:
        yield session

async def get_merchant_service(db: AsyncSession = Depends(get_db)) -> MerchantService:
    return MerchantService(MerchantRepository(db))

@router.get("/merchants/{mid}")
async def get_merchant(
    mid: str,
    service: MerchantService = Depends(get_merchant_service),
) -> MerchantResponse:
    return await service.find_by_mid(mid)
```

## Dependency Hierarchy

```
Route Handler
├── Depends(get_merchant_service)
│   └── Depends(get_db)        # AsyncSession
├── Depends(get_current_user)
│   └── Depends(get_token)     # From header
└── Depends(get_settings)      # Cached singleton
```

## Class-Based Dependencies

```python
class PaginationParams:
    def __init__(self, page: int = Query(0, ge=0), limit: int = Query(20, ge=1, le=100)):
        self.page = page
        self.limit = limit
        self.offset = page * limit

@router.get("/merchants")
async def list_merchants(
    pagination: PaginationParams = Depends(),
    service: MerchantService = Depends(get_merchant_service),
) -> PaginatedResponse[MerchantResponse]:
    return await service.list(pagination.offset, pagination.limit)
```

## Singleton Dependencies

```python
from functools import lru_cache

@lru_cache
def get_settings() -> Settings:
    return Settings()
```

## Dependency Overrides for Testing

```python
app.dependency_overrides[get_db] = lambda: mock_session
app.dependency_overrides[get_merchant_service] = lambda: FakeMerchantService()
```

## Scoped Dependencies

| Pattern          | Lifetime                | Use Case                    |
| ---------------- | ----------------------- | --------------------------- |
| `yield` function | Per-request (cleanup)   | DB sessions, file handles   |
| `lru_cache`      | Singleton               | Settings, config objects     |
| Plain function   | Per-call                | Stateless transformations   |
| Class with `__call__` | Per-call with state | Parameterized dependencies  |

## Anti-Patterns

- Do NOT instantiate services directly in route handlers -- use `Depends()`
- Do NOT use global mutable state -- use dependency injection for shared resources
- Do NOT forget `yield` cleanup in database session dependencies
- Do NOT nest too many `Depends()` levels -- keep the dependency graph shallow
- Do NOT use `Depends()` for pure data validation -- use Pydantic models instead
