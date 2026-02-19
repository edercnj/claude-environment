# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# FastAPI — Web Patterns

## APIRouter Structure

```python
from fastapi import APIRouter, HTTPException, status, Depends

router = APIRouter(prefix="/api/v1/merchants", tags=["merchants"])

@router.get("", response_model=PaginatedResponse[MerchantResponse])
async def list_merchants(
    pagination: PaginationParams = Depends(),
    service: MerchantService = Depends(get_merchant_service),
) -> PaginatedResponse[MerchantResponse]:
    return await service.list(pagination.offset, pagination.limit)

@router.post("", response_model=MerchantResponse, status_code=status.HTTP_201_CREATED)
async def create_merchant(
    body: CreateMerchantRequest,
    service: MerchantService = Depends(get_merchant_service),
) -> MerchantResponse:
    return await service.create(body)

@router.get("/{merchant_id}", response_model=MerchantResponse)
async def get_merchant(
    merchant_id: int,
    service: MerchantService = Depends(get_merchant_service),
) -> MerchantResponse:
    merchant = await service.find_by_id(merchant_id)
    if not merchant:
        raise HTTPException(status_code=404, detail=f"Merchant {merchant_id} not found")
    return merchant
```

## Pydantic Models

```python
from pydantic import BaseModel, Field, field_validator
from datetime import datetime

class CreateMerchantRequest(BaseModel):
    mid: str = Field(..., min_length=1, max_length=15)
    name: str = Field(..., min_length=1, max_length=100)
    document: str = Field(..., pattern=r"^\d{11,14}$")
    mcc: str = Field(..., min_length=4, max_length=4, pattern=r"^\d{4}$")

class MerchantResponse(BaseModel):
    id: int
    mid: str
    name: str
    document_masked: str
    mcc: str
    status: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
```

## Custom Exception Handlers

```python
class AppException(Exception):
    def __init__(self, status_code: int, detail: str, error_type: str = "internal-error"):
        self.status_code = status_code
        self.detail = detail
        self.error_type = error_type

@app.exception_handler(AppException)
async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "type": f"/errors/{exc.error_type}",
            "title": exc.error_type.replace("-", " ").title(),
            "status": exc.status_code,
            "detail": exc.detail,
            "instance": str(request.url.path),
        },
    )

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    violations = {}
    for error in exc.errors():
        field = ".".join(str(loc) for loc in error["loc"][1:])
        violations.setdefault(field, []).append(error["msg"])
    return JSONResponse(status_code=422, content={
        "type": "/errors/validation-error", "status": 422, "detail": "Validation failed",
        "extensions": {"violations": violations},
    })
```

## Response Models

| Status | Use Case                    | Response Model         |
| ------ | --------------------------- | ---------------------- |
| 200    | GET success                 | `MerchantResponse`     |
| 201    | POST created                | `MerchantResponse`     |
| 204    | DELETE success              | None                   |
| 400    | Validation error            | `ProblemDetail`        |
| 404    | Not found                   | `ProblemDetail`        |
| 409    | Conflict (duplicate)        | `ProblemDetail`        |
| 422    | Request validation error    | `ProblemDetail`        |

## Anti-Patterns

- Do NOT use `dict` returns -- always use Pydantic response models
- Do NOT put business logic in route handlers -- delegate to services
- Do NOT return ORM entities directly -- map to Pydantic response models
- Do NOT use `HTTPException` for all errors -- create domain-specific exceptions
