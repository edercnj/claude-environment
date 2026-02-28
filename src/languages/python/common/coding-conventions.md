# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Python Coding Conventions

## Style Enforcement

- **PEP 8** mandatory
- **ruff** for linting and formatting (replaces flake8 + black + isort)
- Line length: **120 characters** maximum

## Naming Conventions

| Element       | Convention     | Example                    |
| ------------- | -------------- | -------------------------- |
| Function      | snake_case     | `process_order()`          |
| Variable      | snake_case     | `merchant_name`            |
| Class         | PascalCase     | `OrderProcessor`           |
| Constant      | UPPER_SNAKE    | `MAX_RETRY_COUNT`          |
| Module        | snake_case     | `order_processor.py`       |
| Package       | snake_case     | `order_processing`         |
| Private       | _snake_case    | `_internal_state`          |
| Type Variable | PascalCase     | `T`, `ItemType`            |

## Type Hints

Type hints are mandatory on all function signatures.

```python
# CORRECT - fully typed
def find_merchant(merchant_id: str) -> Merchant | None:
    return merchants.get(merchant_id)

def process_orders(orders: list[Order], *, validate: bool = True) -> list[OrderResult]:
    if validate:
        orders = [o for o in orders if o.is_valid()]
    return [process(o) for o in orders]

# FORBIDDEN - no type hints
def find_merchant(merchant_id):
    return merchants.get(merchant_id)
```

## Dataclasses for DTOs

```python
from dataclasses import dataclass, field
from datetime import datetime

@dataclass(frozen=True)
class MerchantResponse:
    id: int
    mid: str
    name: str
    document_masked: str
    status: str
    created_at: datetime

@dataclass
class CreateMerchantRequest:
    mid: str
    name: str
    document: str
    mcc: str
    timeout_enabled: bool = False
```

## Abstract Base Classes

```python
from abc import ABC, abstractmethod

class MerchantRepository(ABC):
    @abstractmethod
    def find_by_mid(self, mid: str) -> Merchant | None: ...

    @abstractmethod
    def save(self, merchant: Merchant) -> Merchant: ...

    @abstractmethod
    def delete(self, merchant_id: int) -> None: ...
```

## String Formatting

```python
# CORRECT - f-strings
message = f"Merchant {merchant.mid} created successfully"
query = f"SELECT * FROM merchants WHERE mid = '{mid}'"

# FORBIDDEN - %-formatting and .format()
message = "Merchant %s created" % merchant.mid
message = "Merchant {} created".format(merchant.mid)
```

## Error Handling

```python
# CORRECT - specific exception types with context
class MerchantNotFoundError(Exception):
    def __init__(self, identifier: str) -> None:
        self.identifier = identifier
        super().__init__(f"Merchant not found: {identifier}")

class InvalidDocumentError(ValueError):
    def __init__(self, document: str) -> None:
        masked = f"{document[:3]}****{document[-2:]}"
        self.document = document
        super().__init__(f"Invalid document: {masked}")

# FORBIDDEN - bare except
try:
    process()
except:
    pass

# CORRECT - specific exception
try:
    merchant = repository.find_by_mid(mid)
except DatabaseError as e:
    logger.error("Database error finding merchant", mid=mid, error=str(e))
    raise ServiceUnavailableError("Database unavailable") from e
```

## Context Managers

```python
# CORRECT - context managers for resources
with open(config_path) as f:
    config = json.load(f)

async with httpx.AsyncClient() as client:
    response = await client.get(url)
```

## Comprehensions

```python
# CORRECT - comprehensions over loops
active_mids = [m.mid for m in merchants if m.status == MerchantStatus.ACTIVE]
merchant_map = {m.mid: m for m in merchants}
unique_mccs = {m.mcc for m in merchants}

# FORBIDDEN - loop for simple transformations
active_mids = []
for m in merchants:
    if m.status == MerchantStatus.ACTIVE:
        active_mids.append(m.mid)
```

## Size Limits

- Max **25 lines** per function
- Max **250 lines** per file
- Max **4 parameters** per function (use dataclass for more)

## Import Ordering

```python
# 1. Standard library
import json
from datetime import datetime
from pathlib import Path

# 2. Third-party
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# 3. Local
from app.domain.models import Merchant
from app.repositories.merchant_repository import MerchantRepository
```

## None Handling

```python
# CORRECT - explicit Optional handling
def find_merchant(mid: str) -> Merchant | None:
    return db.query(Merchant).filter_by(mid=mid).first()

# CORRECT - guard clause
merchant = find_merchant(mid)
if merchant is None:
    raise MerchantNotFoundError(mid)

# Use Path objects over strings
config_path = Path(__file__).parent / "config" / "settings.toml"
```

## Anti-Patterns (FORBIDDEN)

- Bare `except:` without specific exception type
- `print()` for application logging
- Mutable default arguments (`def f(items=[]): ...`)
- `from module import *` (wildcard imports)
- String paths instead of `Path` objects
- `type: ignore` without explanation
- Global mutable state
