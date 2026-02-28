# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# FastAPI — SQLAlchemy Patterns
> Extends: `core/11-database-principles.md`

## Async Engine and Session

```python
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

engine = create_async_engine(settings.database_url, pool_size=10, max_overflow=5, echo=False)
async_session_maker = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_maker() as session:
        yield session
```

## Declarative Models

```python
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy import String, BigInteger, DateTime
from datetime import datetime

class Base(DeclarativeBase):
    pass

class MerchantEntity(Base):
    __tablename__ = "merchants"
    __table_args__ = {"schema": "simulator"}

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    mid: Mapped[str] = mapped_column(String(15), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    document: Mapped[str] = mapped_column(String(14), nullable=False)
    mcc: Mapped[str] = mapped_column(String(4), nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="ACTIVE")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    terminals: Mapped[list["TerminalEntity"]] = relationship(back_populates="merchant")
```

## Repository Pattern

```python
class MerchantRepository:
    def __init__(self, session: AsyncSession):
        self._session = session

    async def find_by_id(self, merchant_id: int) -> MerchantEntity | None:
        return await self._session.get(MerchantEntity, merchant_id)

    async def find_by_mid(self, mid: str) -> MerchantEntity | None:
        stmt = select(MerchantEntity).where(MerchantEntity.mid == mid)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def create(self, entity: MerchantEntity) -> MerchantEntity:
        self._session.add(entity)
        await self._session.commit()
        await self._session.refresh(entity)
        return entity

    async def paginate(self, offset: int, limit: int) -> tuple[list[MerchantEntity], int]:
        count_stmt = select(func.count()).select_from(MerchantEntity)
        data_stmt = select(MerchantEntity).offset(offset).limit(limit).order_by(MerchantEntity.created_at.desc())
        total = (await self._session.execute(count_stmt)).scalar_one()
        items = (await self._session.execute(data_stmt)).scalars().all()
        return list(items), total
```

## Alembic Migrations

```bash
# Initialize
alembic init alembic

# Create migration
alembic revision --autogenerate -m "add_merchant_table"

# Apply
alembic upgrade head

# Rollback
alembic downgrade -1
```

## Anti-Patterns

- Do NOT use synchronous SQLAlchemy in FastAPI -- always use async engine and session
- Do NOT expose ORM entities in API responses -- map to Pydantic models
- Do NOT forget `expire_on_commit=False` for async sessions
- Do NOT call `session.commit()` in multiple places -- commit once per unit of work
- Do NOT write raw SQL unless the ORM query is insufficient
