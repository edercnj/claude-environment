# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Python Libraries

## Mandatory

| Library    | Purpose          | Justification                                   |
| ---------- | ---------------- | ----------------------------------------------- |
| pydantic   | Validation       | Runtime validation, serialization, type safety   |
| structlog  | Logging          | Structured logging, JSON output, context binding |
| pytest     | Testing          | De facto standard, fixtures, parametrize         |

### Pydantic (Validation)

```python
from pydantic import BaseModel, Field, field_validator

class CreateMerchantRequest(BaseModel):
    mid: str = Field(min_length=1, max_length=15)
    name: str = Field(min_length=1, max_length=100)
    document: str = Field(pattern=r"^\d{11,14}$")
    mcc: str = Field(min_length=4, max_length=4, pattern=r"^\d{4}$")

    @field_validator("document")
    @classmethod
    def validate_document(cls, v: str) -> str:
        if len(v) not in (11, 14):
            raise ValueError("Document must be CPF (11) or CNPJ (14)")
        return v
```

### Structlog (Logging)

```python
import structlog

logger = structlog.get_logger()

logger.info("merchant_created", merchant_id=merchant.id, mid=merchant.mid)
logger.error("processing_failed", error=str(e), mti=mti, stan=stan)

# Configuration
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer(),
    ],
)
```

### Alternative: Loguru

```python
from loguru import logger

logger.info("Merchant {mid} created", mid=merchant.mid)
logger.bind(mti=mti, stan=stan).error("Processing failed: {error}", error=str(e))
```

## Recommended

| Library     | Purpose            | When to Use                           |
| ----------- | ------------------ | ------------------------------------- |
| httpx       | HTTP client        | External API calls (async support)    |
| alembic     | DB migrations      | SQLAlchemy projects                   |
| sqlalchemy  | ORM                | Complex database interactions         |
| tenacity    | Retry logic        | Resilient external calls              |
| uvicorn     | ASGI server        | FastAPI deployment                    |
| celery      | Task queue         | Background job processing             |
| redis       | Cache/queue        | Caching, pub/sub, rate limiting       |

### Httpx Example

```python
import httpx

async with httpx.AsyncClient(timeout=10.0) as client:
    response = await client.get(
        "https://api.example.com/merchants",
        headers={"Authorization": f"Bearer {token}"},
    )
    response.raise_for_status()
    data = response.json()
```

### Tenacity (Retry)

```python
from tenacity import retry, stop_after_attempt, wait_exponential

@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=10),
)
async def fetch_external_data(url: str) -> dict:
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        response.raise_for_status()
        return response.json()
```

## Prohibited

| Library    | Reason                                    | Alternative              |
| ---------- | ----------------------------------------- | ------------------------ |
| print()    | Not structured, no levels, no context     | structlog or loguru      |
| requests   | No async support, slower                  | httpx                    |
| Flask      | Sync-only, limited for new projects       | FastAPI                  |
| nose       | Unmaintained                              | pytest                   |
| mock       | Use `unittest.mock` or `pytest-mock`      | pytest-mock              |

## Package Manager

- **uv** or **poetry** recommended
- Lock file MUST be committed (`uv.lock` or `poetry.lock`)
- Pin all direct dependencies to exact versions
- `pyproject.toml` as single project config file

## Security

- Run `pip audit` or `safety check` regularly
- No packages with known critical vulnerabilities
- Virtual environment mandatory (never install globally)
