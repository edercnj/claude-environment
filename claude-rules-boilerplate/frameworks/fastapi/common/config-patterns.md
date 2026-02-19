# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# FastAPI — Configuration Patterns
> Extends: `core/10-infrastructure-principles.md`

## pydantic-settings BaseSettings

```python
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", case_sensitive=False)

    app_name: str = "authorizer-simulator"
    environment: str = Field(default="development", alias="ENV")
    debug: bool = False

    # Server
    host: str = "0.0.0.0"
    port: int = 8000

    # Database
    database_url: str = Field(..., alias="DATABASE_URL")
    db_pool_size: int = 10
    db_max_overflow: int = 5

    # Security
    api_key: str = Field(..., min_length=16)
    cors_origins: list[str] = ["*"]

    # Observability
    otel_enabled: bool = False
    otel_endpoint: str = "http://otel-collector:4317"
    log_level: str = "info"
```

## Singleton Access

```python
from functools import lru_cache

@lru_cache
def get_settings() -> Settings:
    return Settings()
```

## Environment-Based Loading

| Variable      | Development            | Test                      | Production        |
| ------------- | ---------------------- | ------------------------- | ----------------- |
| ENV           | development            | test                      | production        |
| DATABASE_URL  | postgresql+asyncpg://  | sqlite+aiosqlite://       | from secret       |
| DEBUG         | true                   | false                     | false             |
| LOG_LEVEL     | debug                  | warning                   | info              |
| OTEL_ENABLED  | false                  | false                     | true              |
| API_KEY       | dev-key-1234567890     | test-key-1234567890       | from secret       |

## Usage in Application

```python
from fastapi import FastAPI, Depends

app = FastAPI(title=get_settings().app_name, debug=get_settings().debug)

@app.get("/health")
async def health(settings: Settings = Depends(get_settings)) -> dict:
    return {"status": "up", "environment": settings.environment}
```

## Override in Tests

```python
def get_test_settings() -> Settings:
    return Settings(database_url="sqlite+aiosqlite:///test.db", api_key="test-key-1234567890")

app.dependency_overrides[get_settings] = get_test_settings
```

## Environment Files

| File          | Purpose              | Git |
| ------------- | -------------------- | --- |
| `.env`        | Local dev defaults   | NO  |
| `.env.example`| Template             | YES |
| `.env.test`   | Test overrides       | YES |

## Anti-Patterns

- Do NOT scatter `os.getenv()` calls throughout the codebase -- centralize in Settings
- Do NOT skip validation -- pydantic validates types and constraints at startup
- Do NOT commit `.env` with real secrets
- Do NOT create Settings instances directly in application code -- use `lru_cache` singleton
