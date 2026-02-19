# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Axum — Web Patterns (Router, Handlers, Extractors, Error Handling)

## Router Setup

```rust
use axum::{Router, routing::{get, post, put, delete}};

pub fn create_router(state: AppState) -> Router {
    Router::new()
        .route("/api/v1/merchants", get(list_merchants).post(create_merchant))
        .route("/api/v1/merchants/:id", get(get_merchant).put(update_merchant).delete(delete_merchant))
        .route("/health", get(health_check))
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}
```

## Handler Functions

```rust
async fn create_merchant(
    State(state): State<AppState>,
    Json(payload): Json<CreateMerchantRequest>,
) -> Result<(StatusCode, Json<MerchantResponse>), AppError> {
    let merchant = state.merchant_service.create(payload).await?;
    Ok((StatusCode::CREATED, Json(merchant)))
}

async fn get_merchant(
    State(state): State<AppState>,
    Path(id): Path<i64>,
) -> Result<Json<MerchantResponse>, AppError> {
    let merchant = state.merchant_service.find_by_id(id).await?;
    Ok(Json(merchant))
}

async fn list_merchants(
    State(state): State<AppState>,
    Query(params): Query<PaginationParams>,
) -> Result<Json<PaginatedResponse<MerchantResponse>>, AppError> {
    let result = state.merchant_service.list(params.page, params.limit).await?;
    Ok(Json(result))
}

async fn delete_merchant(
    State(state): State<AppState>,
    Path(id): Path<i64>,
) -> Result<StatusCode, AppError> {
    state.merchant_service.deactivate(id).await?;
    Ok(StatusCode::NO_CONTENT)
}
```

## Extractors

| Extractor       | Purpose                                    |
| --------------- | ------------------------------------------ |
| `Path(id)`      | Extract path parameters                   |
| `Query(params)` | Extract query string parameters            |
| `Json(body)`    | Deserialize JSON request body              |
| `State(state)`  | Access shared application state            |
| `Extension(x)`  | Access request extensions from middleware   |
| `TypedHeader(h)`| Extract typed headers                      |

## Request/Response Types

```rust
#[derive(Deserialize, Validate)]
pub struct CreateMerchantRequest {
    #[validate(length(min = 1, max = 15))]
    pub mid: String,
    #[validate(length(min = 1, max = 100))]
    pub name: String,
    #[validate(regex(path = "DOCUMENT_RE"))]
    pub document: String,
    #[validate(length(equal = 4))]
    pub mcc: String,
}

#[derive(Serialize)]
pub struct MerchantResponse {
    pub id: i64,
    pub mid: String,
    pub name: String,
    pub document_masked: String,
    pub mcc: String,
    pub status: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Deserialize)]
pub struct PaginationParams {
    #[serde(default)]
    pub page: i64,
    #[serde(default = "default_limit")]
    pub limit: i64,
}
fn default_limit() -> i64 { 20 }
```

## Error Handling

```rust
pub enum AppError {
    NotFound(String),
    Conflict(String),
    Validation(String),
    Internal(anyhow::Error),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, problem) = match self {
            AppError::NotFound(detail) => (StatusCode::NOT_FOUND, ProblemDetail {
                r#type: "/errors/not-found".into(), title: "Not Found".into(), status: 404, detail,
            }),
            AppError::Conflict(detail) => (StatusCode::CONFLICT, ProblemDetail {
                r#type: "/errors/conflict".into(), title: "Conflict".into(), status: 409, detail,
            }),
            AppError::Validation(detail) => (StatusCode::BAD_REQUEST, ProblemDetail {
                r#type: "/errors/bad-request".into(), title: "Bad Request".into(), status: 400, detail,
            }),
            AppError::Internal(err) => {
                tracing::error!("Internal error: {:?}", err);
                (StatusCode::INTERNAL_SERVER_ERROR, ProblemDetail {
                    r#type: "/errors/internal-error".into(), title: "Internal Error".into(),
                    status: 500, detail: "Internal server error".into(),
                })
            }
        };
        (status, Json(problem)).into_response()
    }
}

impl From<sqlx::Error> for AppError {
    fn from(err: sqlx::Error) -> Self {
        AppError::Internal(err.into())
    }
}
```

## Shared State

```rust
#[derive(Clone)]
pub struct AppState {
    pub merchant_service: Arc<MerchantService>,
    pub config: Arc<AppConfig>,
}
```

## Anti-Patterns

- Do NOT use `unwrap()` in handler functions -- return `Result<T, AppError>`
- Do NOT put business logic in handlers -- delegate to service structs
- Do NOT return raw database rows -- map to response structs with serde
- Do NOT forget to add `#[derive(Clone)]` on `AppState`
- Do NOT use `String` for error responses -- implement `IntoResponse` for typed errors
