# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Django — Configuration Patterns
> Extends: `core/10-infrastructure-principles.md`

## django-environ Setup

```python
# settings/base.py
import environ

env = environ.Env(
    DEBUG=(bool, False),
    ALLOWED_HOSTS=(list, []),
    LOG_LEVEL=(str, "INFO"),
)
environ.Env.read_env(BASE_DIR / ".env")

SECRET_KEY = env("SECRET_KEY")
DEBUG = env("DEBUG")
ALLOWED_HOSTS = env("ALLOWED_HOSTS")

DATABASES = {
    "default": env.db("DATABASE_URL", default="postgres://simulator:simulator@localhost:5432/simulator"),
}
```

## Split Settings per Environment

```
settings/
├── __init__.py       # Loads based on DJANGO_ENV
├── base.py           # Shared settings
├── development.py    # Dev overrides
├── test.py           # Test overrides
└── production.py     # Prod overrides
```

```python
# settings/__init__.py
import os

env = os.environ.get("DJANGO_ENV", "development")
if env == "production":
    from .production import *
elif env == "test":
    from .test import *
else:
    from .development import *
```

## Development Settings

```python
# settings/development.py
from .base import *

DEBUG = True
DATABASES["default"] = env.db("DATABASE_URL", default="postgres://simulator:simulator@localhost:5432/simulator")
REST_FRAMEWORK["DEFAULT_RENDERER_CLASSES"] = ["rest_framework.renderers.BrowsableAPIRenderer", "rest_framework.renderers.JSONRenderer"]
LOGGING["handlers"]["console"]["level"] = "DEBUG"
```

## Test Settings

```python
# settings/test.py
from .base import *

DEBUG = False
DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": ":memory:"}}
PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]
EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
```

## Production Settings

```python
# settings/production.py
from .base import *

DEBUG = False
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000
LOGGING["handlers"]["console"]["formatter"] = "json"
```

## Per-Environment Differences

| Setting          | Development | Test      | Production     |
| ---------------- | ----------- | --------- | -------------- |
| DEBUG            | True        | False     | False          |
| DATABASE         | PostgreSQL  | SQLite    | PostgreSQL     |
| LOG_LEVEL        | DEBUG       | WARNING   | INFO           |
| SSL_REDIRECT     | False       | False     | True           |
| CORS_ALLOW_ALL   | True        | True      | False          |

## REST Framework Settings

```python
REST_FRAMEWORK = {
    "DEFAULT_PAGINATION_CLASS": "core.pagination.StandardPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    "EXCEPTION_HANDLER": "core.exceptions.custom_exception_handler",
    "DEFAULT_FILTER_BACKENDS": ["django_filters.rest_framework.DjangoFilterBackend"],
}
```

## Anti-Patterns

- Do NOT hardcode `SECRET_KEY` -- always load from environment
- Do NOT use `DEBUG=True` in production
- Do NOT commit `.env` with real secrets
- Do NOT use SQLite in production -- always PostgreSQL
- Do NOT put all settings in one file -- split by environment
