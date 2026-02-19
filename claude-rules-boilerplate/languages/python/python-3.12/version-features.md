# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Python 3.12 Version Features

## Type Parameter Syntax (PEP 695)

New syntax for generic classes and functions using `[T]` instead of `TypeVar`.

```python
# OLD - verbose TypeVar
from typing import TypeVar, Generic

T = TypeVar("T")
K = TypeVar("K")
V = TypeVar("V")

class Repository(Generic[T]):
    def find_by_id(self, id: str) -> T | None: ...

# NEW (3.12) - inline type parameters
class Repository[T]:
    def find_by_id(self, id: str) -> T | None: ...

class KeyValueStore[K, V]:
    def get(self, key: K) -> V | None: ...
    def put(self, key: K, value: V) -> None: ...

# Generic functions
def first[T](items: list[T]) -> T | None:
    return items[0] if items else None

# Bounded type parameters
def process[T: (int, float)](value: T) -> T:
    return value * 2
```

## `type` Statement for Type Aliases (PEP 695)

```python
# OLD
from typing import TypeAlias

MerchantId: TypeAlias = str
Point: TypeAlias = tuple[int, int]
Callback: TypeAlias = Callable[[str, int], bool]

# NEW (3.12)
type MerchantId = str
type Point = tuple[int, int]
type Callback = Callable[[str, int], bool]

# Generic type aliases
type Matrix[T] = list[list[T]]
type Handler[T] = Callable[[T], None]
type Result[T, E] = T | E

# Self-referencing (recursive types)
type Json = str | int | float | bool | None | list[Json] | dict[str, Json]
type TreeNode[T] = tuple[T, list[TreeNode[T]]]
```

### Practical Use

```python
type MerchantMap = dict[str, Merchant]
type TransactionFilter = Callable[[Transaction], bool]
type PaginatedResult[T] = tuple[list[T], int]  # (items, total_count)

def list_merchants(
    filters: list[TransactionFilter],
    page: int = 0,
    limit: int = 20,
) -> PaginatedResult[Merchant]:
    ...
```

## F-String Improvements (PEP 701)

Nested quotes, backslashes, and multi-line expressions now allowed inside f-strings.

```python
# Nested quotes (NEW in 3.12)
message = f"Merchant '{merchant.name}' with MID \"{merchant.mid}\" created"

# Multi-line expressions inside f-strings
report = f"Total: {
    sum(
        t.amount
        for t in transactions
        if t.status == 'approved'
    )
}"

# Backslashes inside f-strings (NEW in 3.12)
formatted = f"Items: {'\n'.join(item.name for item in items)}"

# Complex expressions
log_entry = f"[{datetime.now():%Y-%m-%d %H:%M:%S}] {
    'APPROVED' if result.code == '00' else 'DENIED'
}: amount={result.amount:.2f}"
```

## Per-Interpreter GIL (PEP 684)

Experimental support for separate GIL per sub-interpreter, enabling true parallelism.

```python
# Experimental - requires C API
# Each sub-interpreter gets its own GIL
# Enables true parallel execution within a single process

# Practical impact: future frameworks may leverage this for
# concurrent request handling without multiprocessing overhead

# Current usage is via C extension modules
# Python-level API expected in future versions
```

## Improved Error Messages

```python
# Before 3.12
# NameError: name 'respons' is not defined

# Python 3.12
# NameError: name 'respons' is not defined. Did you mean: 'response'?

# Import errors
# ImportError: cannot import name 'Merchant' from 'app.models'.
# Did you mean: 'MerchantEntity'?

# Syntax errors with better context
# SyntaxError: expected ':' after 'if' statement
#     if condition
#                ^

# Type errors
# TypeError: MerchantService.create() missing 1 required keyword argument: 'name'
```

## `override` Decorator (PEP 698, from typing_extensions)

```python
from typing import override

class BaseRepository[T]:
    def find_by_id(self, id: str) -> T | None:
        raise NotImplementedError

class MerchantRepository(BaseRepository[Merchant]):
    @override
    def find_by_id(self, id: str) -> Merchant | None:
        return self.db.query(Merchant).get(id)

    # Typo caught at type-check time
    @override
    def find_by_idd(self, id: str) -> Merchant | None:  # Error: no matching base method
        ...
```

## Recommended pyproject.toml (3.12)

```toml
[project]
requires-python = ">=3.12"

[tool.ruff]
target-version = "py312"
line-length = 120

[tool.ruff.lint]
select = ["E", "F", "I", "UP", "B", "SIM", "TCH"]

[tool.mypy]
python_version = "3.12"
strict = true
warn_return_any = true
warn_unused_configs = true
```
