---
name: fastapi-patterns
description: "FastAPI-specific patterns: Depends() DI, SQLAlchemy/Tortoise ORM data access, Pydantic models, APIRouter, BaseSettings config, httpx async testing, uvicorn deployment. Internal reference for agents producing FastAPI code."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: FastAPI Patterns

## Purpose

Provides FastAPI-specific implementation patterns that supplement the generic layer templates. Agents reference this pack when generating code for a Python + FastAPI project.

---

## 1. Dependency Injection

### Depends() Function

```python
from fastapi import Depends, FastAPI

async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        yield session


async def get_merchant_repository(
    session: AsyncSession = Depends(get_db_session),
) -> MerchantRepository:
    return MerchantRepository(session)


async def get_merchant_service(
    repository: MerchantRepository = Depends(get_merchant_repository),
    logger: Logger = Depends(get_logger),
) -> MerchantService:
    return MerchantService(repository=repository, logger=logger)
```

### Yield Dependencies (Lifecycle Management)

```python
async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


async def get_redis_client() -> AsyncGenerator[Redis, None]:
    client = Redis.from_url(settings.redis_url)
    try:
        yield client
    finally:
        await client.close()
```

### App-Scoped Dependencies (Lifespan)

```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    # Startup
    engine = create_async_engine(settings.database_url, pool_size=settings.db_pool_size)
    app.state.engine = engine
    app.state.session_factory = async_sessionmaker(engine, class_=AsyncSession)
    yield
    # Shutdown
    await engine.dispose()


app = FastAPI(lifespan=lifespan)
```

### Scoped Dependencies

| Scope | Pattern | Lifecycle |
|-------|---------|-----------|
| Request-scoped | `Depends(get_db_session)` with `yield` | Created and destroyed per request |
| App-scoped | `lifespan` context manager | Created at startup, destroyed at shutdown |
| Singleton | Module-level instance | Lives for process duration |

### FORBIDDEN

- Global mutable state (`db_session = None` at module level)
- Using `import` as dependency injection (tight coupling)
- Sync blocking calls inside `Depends()` async functions
- Mutable default arguments in dependency functions

---

## 2. Data Access (SQLAlchemy / Tortoise ORM)

### SQLAlchemy Path

#### AsyncSession Setup

```python
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

engine = create_async_engine(
    settings.database_url,
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True,
)

async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)
```

#### Model Definition

```python
from sqlalchemy import String, DateTime, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class MerchantModel(Base):
    __tablename__ = "merchants"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    mid: Mapped[str] = mapped_column(String(15), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="ACTIVE")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    transactions: Mapped[list["TransactionModel"]] = relationship(
        back_populates="merchant",
        lazy="selectin",
    )
```

#### Repository Pattern

```python
class MerchantRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def find_by_id(self, merchant_id: uuid.UUID) -> MerchantModel | None:
        return await self._session.get(MerchantModel, merchant_id)

    async def find_by_mid(self, mid: str) -> MerchantModel | None:
        stmt = select(MerchantModel).where(MerchantModel.mid == mid)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def find_by_status(
        self, status: str, offset: int = 0, limit: int = 20
    ) -> list[MerchantModel]:
        stmt = (
            select(MerchantModel)
            .where(MerchantModel.status == status)
            .order_by(MerchantModel.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def create(self, merchant: MerchantModel) -> MerchantModel:
        self._session.add(merchant)
        await self._session.flush()
        await self._session.refresh(merchant)
        return merchant

    async def count_by_status(self, status: str) -> int:
        stmt = select(func.count()).select_from(MerchantModel).where(MerchantModel.status == status)
        result = await self._session.execute(stmt)
        return result.scalar_one()
```

#### Relationships with lazy="selectin"

```python
# Eager load in one query — avoids N+1
transactions: Mapped[list["TransactionModel"]] = relationship(
    back_populates="merchant",
    lazy="selectin",
)

# Or explicit eager load in query
stmt = select(MerchantModel).options(selectinload(MerchantModel.transactions))
```

#### Alembic Migrations

```bash
# Initialize
alembic init alembic

# Generate migration
alembic revision --autogenerate -m "add_merchant_table"

# Apply migrations
alembic upgrade head

# Rollback
alembic downgrade -1
```

### Tortoise ORM Path

#### Model Definition

```python
from tortoise import fields
from tortoise.models import Model


class Merchant(Model):
    id = fields.UUIDField(pk=True, default=uuid.uuid4)
    mid = fields.CharField(max_length=15, unique=True)
    name = fields.CharField(max_length=100)
    status = fields.CharField(max_length=20, default="ACTIVE")
    created_at = fields.DatetimeField(auto_now_add=True)
    updated_at = fields.DatetimeField(auto_now=True)

    transactions: fields.ReverseRelation["Transaction"]

    class Meta:
        table = "merchants"
        ordering = ["-created_at"]
```

#### QuerySet API

```python
# Find by ID
merchant = await Merchant.get_or_none(id=merchant_id)

# Filter with pagination
merchants = await Merchant.filter(status="ACTIVE").offset(0).limit(20)

# Count
total = await Merchant.filter(status="ACTIVE").count()

# Create
merchant = await Merchant.create(mid="MID001", name="Test Merchant")

# Prefetch related
merchant = await Merchant.get(id=merchant_id).prefetch_related("transactions")
```

#### Aerich Migrations

```bash
# Initialize
aerich init -t app.config.TORTOISE_ORM

# Generate migration
aerich migrate --name add_merchant_table

# Apply
aerich upgrade
```

---

## 3. Web/HTTP

### Path Operations

```python
from fastapi import APIRouter, HTTPException, status, Query

router = APIRouter(prefix="/api/v1/merchants", tags=["merchants"])


@router.get("", response_model=PaginatedResponse[MerchantResponse])
async def list_merchants(
    page: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
    service: MerchantService = Depends(get_merchant_service),
) -> PaginatedResponse[MerchantResponse]:
    merchants, total = await service.find_all(page=page, limit=limit)
    items = [MerchantResponse.model_validate(m, from_attributes=True) for m in merchants]
    return PaginatedResponse.of(items=items, page=page, limit=limit, total=total)


@router.post("", response_model=MerchantResponse, status_code=status.HTTP_201_CREATED)
async def create_merchant(
    body: CreateMerchantRequest,
    service: MerchantService = Depends(get_merchant_service),
) -> MerchantResponse:
    merchant = await service.create(body)
    return MerchantResponse.model_validate(merchant, from_attributes=True)


@router.get("/{merchant_id}", response_model=MerchantResponse)
async def get_merchant(
    merchant_id: uuid.UUID,
    service: MerchantService = Depends(get_merchant_service),
) -> MerchantResponse:
    merchant = await service.find_by_id(merchant_id)
    if merchant is None:
        raise HTTPException(status_code=404, detail=f"Merchant {merchant_id} not found")
    return MerchantResponse.model_validate(merchant, from_attributes=True)


@router.delete("/{merchant_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_merchant(
    merchant_id: uuid.UUID,
    service: MerchantService = Depends(get_merchant_service),
) -> None:
    await service.deactivate(merchant_id)
```

### Pydantic Models (Request/Response)

```python
from pydantic import BaseModel, Field, ConfigDict


class CreateMerchantRequest(BaseModel):
    mid: str = Field(min_length=1, max_length=15)
    name: str = Field(min_length=1, max_length=100)
    category: MerchantCategory | None = None


class MerchantResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    mid: str
    name: str
    status: str
    created_at: datetime


class PaginatedResponse(BaseModel, Generic[T]):
    items: list[T]
    page: int
    limit: int
    total: int
    total_pages: int

    @classmethod
    def of(cls, items: list[T], page: int, limit: int, total: int) -> "PaginatedResponse[T]":
        return cls(
            items=items,
            page=page,
            limit=limit,
            total=total,
            total_pages=(total + limit - 1) // limit,
        )
```

### Custom Exception Handler (RFC 7807)

```python
from fastapi import Request
from fastapi.responses import JSONResponse


class AppException(Exception):
    def __init__(self, status_code: int, detail: str, title: str = "Error") -> None:
        self.status_code = status_code
        self.detail = detail
        self.title = title


class NotFoundError(AppException):
    def __init__(self, detail: str) -> None:
        super().__init__(status_code=404, detail=detail, title="Not Found")


class ConflictError(AppException):
    def __init__(self, detail: str) -> None:
        super().__init__(status_code=409, detail=detail, title="Conflict")


async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "type": "about:blank",
            "title": exc.title,
            "status": exc.status_code,
            "detail": exc.detail,
            "instance": str(request.url.path),
        },
    )


app.add_exception_handler(AppException, app_exception_handler)
```

### BackgroundTasks

```python
from fastapi import BackgroundTasks


async def send_notification(merchant_id: uuid.UUID) -> None:
    # Long-running task
    await notification_service.notify(merchant_id)


@router.post("", response_model=MerchantResponse, status_code=status.HTTP_201_CREATED)
async def create_merchant(
    body: CreateMerchantRequest,
    background_tasks: BackgroundTasks,
    service: MerchantService = Depends(get_merchant_service),
) -> MerchantResponse:
    merchant = await service.create(body)
    background_tasks.add_task(send_notification, merchant.id)
    return MerchantResponse.model_validate(merchant, from_attributes=True)
```

---

## 4. Configuration

### Pydantic BaseSettings

```python
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Application
    app_name: str = "merchant-api"
    debug: bool = False
    port: int = 8000

    # Database
    database_url: str
    db_pool_size: int = 20
    db_max_overflow: int = 10

    # Auth
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    jwt_expiration_minutes: int = 30

    # Redis
    redis_url: str = "redis://localhost:6379/0"
```

### Settings as Dependency

```python
from functools import lru_cache


@lru_cache
def get_settings() -> Settings:
    return Settings()


@router.get("/health")
async def health(settings: Settings = Depends(get_settings)) -> dict[str, str]:
    return {"app": settings.app_name, "status": "healthy"}
```

### Environment Validation

```python
# .env
DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/merchants
JWT_SECRET=super-secret-key-at-least-32-chars-long
REDIS_URL=redis://localhost:6379/0

# Settings auto-validates on instantiation
# Missing required fields raise ValidationError at startup
settings = Settings()  # Fails fast if DATABASE_URL or JWT_SECRET missing
```

---

## 5. Testing

### httpx AsyncClient with ASGITransport

```python
import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.dependencies import get_merchant_service


@pytest.fixture
def mock_service() -> MagicMock:
    return MagicMock(spec=MerchantService)


@pytest.fixture
def client(mock_service: MagicMock) -> AsyncClient:
    app.dependency_overrides[get_merchant_service] = lambda: mock_service
    yield AsyncClient(transport=ASGITransport(app=app), base_url="http://test")
    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_get_merchant(client: AsyncClient, mock_service: MagicMock) -> None:
    merchant = MerchantModel(id=uuid.uuid4(), mid="MID001", name="Test", status="ACTIVE")
    mock_service.find_by_id.return_value = merchant

    response = await client.get(f"/api/v1/merchants/{merchant.id}")

    assert response.status_code == 200
    assert response.json()["mid"] == "MID001"


@pytest.mark.asyncio
async def test_get_merchant_not_found(client: AsyncClient, mock_service: MagicMock) -> None:
    mock_service.find_by_id.return_value = None

    response = await client.get(f"/api/v1/merchants/{uuid.uuid4()}")

    assert response.status_code == 404


@pytest.mark.asyncio
async def test_create_merchant_validation(client: AsyncClient) -> None:
    response = await client.post("/api/v1/merchants", json={"mid": ""})

    assert response.status_code == 422
```

### Dependency Overrides

```python
# Override DB session for testing
async def get_test_db_session() -> AsyncGenerator[AsyncSession, None]:
    async with test_session_factory() as session:
        yield session

app.dependency_overrides[get_db_session] = get_test_db_session
```

### conftest.py

```python
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

TEST_DATABASE_URL = "postgresql+asyncpg://test:test@localhost:5432/test_db"


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session")
async def engine():
    engine = create_async_engine(TEST_DATABASE_URL)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


@pytest.fixture
async def db_session(engine) -> AsyncGenerator[AsyncSession, None]:
    session_factory = async_sessionmaker(engine, class_=AsyncSession)
    async with session_factory() as session:
        yield session
        await session.rollback()
```

---

## 6. Build & Deployment

### Uvicorn ASGI Server

```bash
# Development with auto-reload
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Production (single worker)
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1
```

### Gunicorn with UvicornWorker (Production)

```bash
gunicorn app.main:app \
  --worker-class uvicorn.workers.UvicornWorker \
  --workers 4 \
  --bind 0.0.0.0:8000 \
  --timeout 120 \
  --access-logfile -
```

### Docker Multi-Stage Build

```dockerfile
# Stage 1: Build
FROM python:3.12 AS builder
WORKDIR /app
RUN pip install --no-cache-dir poetry
COPY pyproject.toml poetry.lock ./
RUN poetry export -f requirements.txt --output requirements.txt --without-hashes
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt
COPY . .

# Stage 2: Production
FROM python:3.12-slim
WORKDIR /app
COPY --from=builder /install /usr/local
COPY --from=builder /app .

RUN useradd --create-home appuser
USER appuser

EXPOSE 8000
CMD ["gunicorn", "app.main:app", "--worker-class", "uvicorn.workers.UvicornWorker", "--workers", "4", "--bind", "0.0.0.0:8000"]
```

### pyproject.toml (Relevant Section)

```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
filterwarnings = ["error", "ignore::DeprecationWarning"]
```

---

## Anti-Patterns (FastAPI-Specific)

- Sync DB calls in async handlers (blocks the event loop, destroys throughput)
- Missing type hints on path operation parameters (FastAPI cannot infer validation)
- Business logic in route handlers (move to service layer)
- `*args` / `**kwargs` in public API function signatures (breaks OpenAPI schema generation)
- Global SQLAlchemy session instance (not thread-safe, causes data corruption)
- Missing Pydantic model for request body (no validation, no OpenAPI docs)
- Using `response_model=dict` instead of a typed Pydantic model
- `from app.database import session` as a module-level singleton
- Blocking I/O in `async def` endpoints (use `def` for sync or run in executor)
- Missing `expire_on_commit=False` on async session factory (causes lazy load errors)
