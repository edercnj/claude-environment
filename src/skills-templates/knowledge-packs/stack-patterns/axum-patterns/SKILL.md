---
name: axum-patterns
description: "Axum-specific patterns: extractors, Router composition, Tower middleware, sqlx async data access, config crate layered config, tokio testing, IntoResponse error handling. Internal reference for agents producing Axum code."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Axum Patterns

## Purpose

Provides Axum-specific implementation patterns that supplement the generic layer templates. Agents reference this pack when generating code for a Rust + Axum project.

---

## 1. Extractors

### Built-In Extractors

```rust
use axum::extract::{Path, Query, Json, State};
use serde::Deserialize;

#[derive(Deserialize)]
struct ListParams {
    page: Option<u32>,
    limit: Option<u32>,
    status: Option<String>,
}

// Path extractor — captures route parameters
async fn get_merchant(
    State(state): State<AppState>,
    Path(id): Path<i64>,
) -> Result<Json<MerchantResponse>, AppError> {
    let merchant = state.merchant_service.find_by_id(id).await?;
    Ok(Json(merchant.into()))
}

// Query extractor — parses query string
async fn list_merchants(
    State(state): State<AppState>,
    Query(params): Query<ListParams>,
) -> Result<Json<PaginatedResponse<MerchantResponse>>, AppError> {
    let page = params.page.unwrap_or(0);
    let limit = params.limit.unwrap_or(20);
    let result = state.merchant_service.find_all(page, limit, params.status).await?;
    Ok(Json(result.into()))
}

// Json extractor — deserializes request body
async fn create_merchant(
    State(state): State<AppState>,
    Json(payload): Json<CreateMerchantRequest>,
) -> Result<(StatusCode, Json<MerchantResponse>), AppError> {
    payload.validate()?;
    let merchant = state.merchant_service.create(payload).await?;
    Ok((StatusCode::CREATED, Json(merchant.into())))
}
```

### Extractor Ordering

Body extractors (`Json`, `Form`) consume the request body and **must be the last extractor**:

```rust
// CORRECT: body extractor last
async fn handler(
    State(state): State<AppState>,
    Path(id): Path<i64>,
    Json(body): Json<UpdateRequest>,
) -> Result<impl IntoResponse, AppError> { /* ... */ }

// WRONG: body extractor before Path — will not compile
// async fn handler(
//     Json(body): Json<UpdateRequest>,
//     Path(id): Path<i64>,
// ) -> ... { }
```

### Custom Extractor

```rust
use axum::extract::FromRequestParts;
use axum::http::request::Parts;

#[derive(Debug, Clone)]
struct AuthenticatedUser {
    user_id: String,
    roles: Vec<String>,
}

#[async_trait]
impl<S> FromRequestParts<S> for AuthenticatedUser
where
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let auth_header = parts
            .headers
            .get("Authorization")
            .and_then(|v| v.to_str().ok())
            .ok_or(AppError::Unauthorized("missing authorization header".into()))?;

        let token = auth_header
            .strip_prefix("Bearer ")
            .ok_or(AppError::Unauthorized("invalid authorization format".into()))?;

        let claims = decode_jwt(token)
            .map_err(|_| AppError::Unauthorized("invalid token".into()))?;

        Ok(AuthenticatedUser {
            user_id: claims.sub,
            roles: claims.roles,
        })
    }
}

// Usage — extractor is automatic
async fn get_profile(user: AuthenticatedUser) -> Json<ProfileResponse> {
    Json(ProfileResponse { user_id: user.user_id })
}
```

---

## 2. Router Composition

### Modular Router Design

```rust
use axum::{Router, routing::{get, post, delete}};

#[derive(Clone)]
struct AppState {
    merchant_service: Arc<dyn MerchantService>,
    db_pool: PgPool,
}

pub fn app(state: AppState) -> Router {
    Router::new()
        .nest("/api/v1", api_routes())
        .with_state(state)
}

fn api_routes() -> Router<AppState> {
    Router::new()
        .merge(health_routes())
        .merge(merchant_routes())
}

fn health_routes() -> Router<AppState> {
    Router::new()
        .route("/health", get(health_check))
}

fn merchant_routes() -> Router<AppState> {
    Router::new()
        .route("/merchants", get(list_merchants).post(create_merchant))
        .route("/merchants/{id}", get(get_merchant).delete(delete_merchant))
}
```

### Nested Routes with Prefix

```rust
fn admin_routes() -> Router<AppState> {
    Router::new()
        .nest("/admin", Router::new()
            .route("/users", get(list_users))
            .route("/users/{id}", get(get_user).delete(delete_user))
            .layer(middleware::from_fn(require_admin_role))
        )
}
```

### Layer Application

```rust
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;

pub fn app(state: AppState) -> Router {
    Router::new()
        .nest("/api/v1", api_routes())
        .layer(TraceLayer::new_for_http())
        .layer(CorsLayer::permissive()) // restrict in production
        .with_state(state)
}
```

---

## 3. Middleware (Tower)

### Tower ServiceBuilder

```rust
use tower::ServiceBuilder;
use tower_http::{
    cors::{Any, CorsLayer},
    compression::CompressionLayer,
    trace::TraceLayer,
    timeout::TimeoutLayer,
};
use std::time::Duration;

pub fn app(state: AppState) -> Router {
    let middleware_stack = ServiceBuilder::new()
        .layer(TraceLayer::new_for_http())
        .layer(CompressionLayer::new())
        .layer(TimeoutLayer::new(Duration::from_secs(30)))
        .layer(
            CorsLayer::new()
                .allow_origin(Any)
                .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE])
                .allow_headers([AUTHORIZATION, CONTENT_TYPE]),
        );

    Router::new()
        .nest("/api/v1", api_routes())
        .layer(middleware_stack)
        .with_state(state)
}
```

### Custom Middleware with from_fn

```rust
use axum::middleware::{self, Next};
use axum::http::Request;
use axum::response::Response;

async fn logging_middleware(
    request: Request<Body>,
    next: Next,
) -> Response {
    let method = request.method().clone();
    let uri = request.uri().clone();
    let start = std::time::Instant::now();

    let response = next.run(request).await;

    let duration = start.elapsed();
    tracing::info!(
        method = %method,
        uri = %uri,
        status = %response.status(),
        duration_ms = %duration.as_millis(),
        "request completed"
    );

    response
}

async fn auth_middleware(
    State(state): State<AppState>,
    mut request: Request<Body>,
    next: Next,
) -> Result<Response, AppError> {
    let token = request
        .headers()
        .get("Authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .ok_or(AppError::Unauthorized("missing token".into()))?;

    let claims = state.auth_service.validate_token(token).await?;
    request.extensions_mut().insert(claims);

    Ok(next.run(request).await)
}

// Apply to specific routes
fn protected_routes() -> Router<AppState> {
    Router::new()
        .route("/merchants", get(list_merchants))
        .layer(middleware::from_fn_with_state(
            app_state.clone(),
            auth_middleware,
        ))
}
```

### Request ID Middleware

```rust
use uuid::Uuid;

async fn request_id_middleware(
    mut request: Request<Body>,
    next: Next,
) -> Response {
    let request_id = request
        .headers()
        .get("X-Request-ID")
        .and_then(|v| v.to_str().ok())
        .map(String::from)
        .unwrap_or_else(|| Uuid::new_v4().to_string());

    request.extensions_mut().insert(RequestId(request_id.clone()));

    let mut response = next.run(request).await;
    response.headers_mut().insert(
        "X-Request-ID",
        request_id.parse().unwrap(),
    );

    response
}
```

---

## 4. Data Access (sqlx)

### Connection Pool Setup

```rust
use sqlx::postgres::{PgPool, PgPoolOptions};

pub async fn create_pool(config: &DatabaseConfig) -> Result<PgPool, sqlx::Error> {
    PgPoolOptions::new()
        .max_connections(config.max_connections)
        .min_connections(config.min_connections)
        .acquire_timeout(Duration::from_secs(config.acquire_timeout_secs))
        .idle_timeout(Duration::from_secs(config.idle_timeout_secs))
        .connect(&config.url)
        .await
}
```

### Compile-Time Checked Queries

```rust
use sqlx::FromRow;

#[derive(Debug, FromRow)]
struct MerchantRow {
    id: i64,
    mid: String,
    name: String,
    status: String,
    created_at: chrono::DateTime<chrono::Utc>,
    updated_at: chrono::DateTime<chrono::Utc>,
}

impl MerchantRepository {
    pub async fn find_by_id(&self, id: i64) -> Result<Option<Merchant>, AppError> {
        let row = sqlx::query_as!(
            MerchantRow,
            r#"SELECT id, mid, name, status, created_at, updated_at
               FROM merchants WHERE id = $1"#,
            id
        )
        .fetch_optional(&self.pool)
        .await
        .map_err(AppError::Database)?;

        Ok(row.map(|r| r.into()))
    }

    pub async fn find_all(
        &self,
        page: u32,
        limit: u32,
        status: Option<&str>,
    ) -> Result<(Vec<Merchant>, i64), AppError> {
        let offset = (page * limit) as i64;
        let limit = limit as i64;

        let total = sqlx::query_scalar!(
            r#"SELECT COUNT(*) as "count!" FROM merchants
               WHERE ($1::text IS NULL OR status = $1)"#,
            status
        )
        .fetch_one(&self.pool)
        .await
        .map_err(AppError::Database)?;

        let rows = sqlx::query_as!(
            MerchantRow,
            r#"SELECT id, mid, name, status, created_at, updated_at
               FROM merchants
               WHERE ($1::text IS NULL OR status = $1)
               ORDER BY created_at DESC
               LIMIT $2 OFFSET $3"#,
            status,
            limit,
            offset
        )
        .fetch_all(&self.pool)
        .await
        .map_err(AppError::Database)?;

        Ok((rows.into_iter().map(Into::into).collect(), total))
    }

    pub async fn create(&self, merchant: &NewMerchant) -> Result<Merchant, AppError> {
        let row = sqlx::query_as!(
            MerchantRow,
            r#"INSERT INTO merchants (mid, name, status, created_at, updated_at)
               VALUES ($1, $2, 'active', NOW(), NOW())
               RETURNING id, mid, name, status, created_at, updated_at"#,
            merchant.mid,
            merchant.name
        )
        .fetch_one(&self.pool)
        .await
        .map_err(AppError::Database)?;

        Ok(row.into())
    }
}
```

### Transaction Support

```rust
pub async fn create_with_audit(&self, merchant: &NewMerchant) -> Result<Merchant, AppError> {
    let mut tx = self.pool.begin().await.map_err(AppError::Database)?;

    let row = sqlx::query_as!(
        MerchantRow,
        r#"INSERT INTO merchants (mid, name, status, created_at, updated_at)
           VALUES ($1, $2, 'active', NOW(), NOW())
           RETURNING id, mid, name, status, created_at, updated_at"#,
        merchant.mid,
        merchant.name
    )
    .fetch_one(&mut *tx)
    .await
    .map_err(AppError::Database)?;

    sqlx::query!(
        r#"INSERT INTO audit_logs (entity_type, entity_id, action, created_at)
           VALUES ('merchant', $1, 'create', NOW())"#,
        row.id
    )
    .execute(&mut *tx)
    .await
    .map_err(AppError::Database)?;

    tx.commit().await.map_err(AppError::Database)?;

    Ok(row.into())
}
```

### Migrations with sqlx-cli

```bash
# Install
cargo install sqlx-cli --no-default-features --features postgres

# Create migration
sqlx migrate add create_merchants

# Run migrations
sqlx migrate run

# Revert last migration
sqlx migrate revert

# Prepare offline query data (for CI without DB)
cargo sqlx prepare
```

---

## 5. Configuration

### Layered Config with config Crate

```rust
use config::{Config, ConfigError, Environment, File};
use serde::Deserialize;

#[derive(Debug, Deserialize, Clone)]
pub struct AppConfig {
    pub server: ServerConfig,
    pub database: DatabaseConfig,
    pub auth: AuthConfig,
    pub log: LogConfig,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
}

#[derive(Debug, Deserialize, Clone)]
pub struct DatabaseConfig {
    pub url: String,
    pub max_connections: u32,
    pub min_connections: u32,
    pub acquire_timeout_secs: u64,
    pub idle_timeout_secs: u64,
}

#[derive(Debug, Deserialize, Clone)]
pub struct AuthConfig {
    pub jwt_secret: String,
    pub token_expiry_secs: u64,
}

#[derive(Debug, Deserialize, Clone)]
pub struct LogConfig {
    pub level: String,
    pub format: String,
}

impl AppConfig {
    pub fn load() -> Result<Self, ConfigError> {
        let run_mode = std::env::var("RUN_MODE").unwrap_or_else(|_| "dev".into());

        let config = Config::builder()
            // Start with default values
            .add_source(File::with_name("config/default"))
            // Layer environment-specific file
            .add_source(File::with_name(&format!("config/{}", run_mode)).required(false))
            // Override with environment variables (APP__SERVER__PORT -> server.port)
            .add_source(
                Environment::with_prefix("APP")
                    .separator("__")
                    .try_parsing(true),
            )
            .build()?;

        config.try_deserialize()
    }
}
```

### Default Config File (config/default.toml)

```toml
[server]
host = "0.0.0.0"
port = 8080

[database]
url = "postgres://user:pass@localhost:5432/mydb"
max_connections = 10
min_connections = 2
acquire_timeout_secs = 5
idle_timeout_secs = 300

[auth]
jwt_secret = "change-me"
token_expiry_secs = 86400

[log]
level = "info"
format = "json"
```

### dotenvy for .env Files

```rust
fn main() {
    // Load .env file if present (non-fatal if missing)
    dotenvy::dotenv().ok();

    let config = AppConfig::load().expect("failed to load configuration");

    // ...
}
```

---

## 6. Testing

### Handler Unit Test with oneshot

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::Body;
    use axum::http::{Request, StatusCode};
    use tower::ServiceExt; // for oneshot

    fn test_app(state: AppState) -> Router {
        Router::new()
            .route("/merchants/{id}", get(get_merchant))
            .with_state(state)
    }

    #[tokio::test]
    async fn test_get_merchant_found() {
        let mock_service = Arc::new(MockMerchantService::new());
        mock_service
            .expect_find_by_id()
            .with(eq(1))
            .returning(|_| Ok(Some(Merchant {
                id: 1,
                mid: "12345".into(),
                name: "Test Shop".into(),
                status: "active".into(),
            })));

        let state = AppState {
            merchant_service: mock_service,
            db_pool: create_test_pool().await,
        };

        let response = test_app(state)
            .oneshot(
                Request::builder()
                    .uri("/merchants/1")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::OK);

        let body = axum::body::to_bytes(response.into_body(), usize::MAX).await.unwrap();
        let merchant: MerchantResponse = serde_json::from_slice(&body).unwrap();
        assert_eq!(merchant.mid, "12345");
    }

    #[tokio::test]
    async fn test_get_merchant_not_found() {
        let mock_service = Arc::new(MockMerchantService::new());
        mock_service
            .expect_find_by_id()
            .with(eq(999))
            .returning(|_| Ok(None));

        let state = AppState {
            merchant_service: mock_service,
            db_pool: create_test_pool().await,
        };

        let response = test_app(state)
            .oneshot(
                Request::builder()
                    .uri("/merchants/999")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn test_create_merchant() {
        let mock_service = Arc::new(MockMerchantService::new());
        mock_service
            .expect_create()
            .returning(|_| Ok(Merchant {
                id: 1,
                mid: "12345".into(),
                name: "New Shop".into(),
                status: "active".into(),
            }));

        let state = AppState {
            merchant_service: mock_service,
            db_pool: create_test_pool().await,
        };

        let app = Router::new()
            .route("/merchants", post(create_merchant))
            .with_state(state);

        let body = serde_json::json!({
            "mid": "12345",
            "name": "New Shop"
        });

        let response = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/merchants")
                    .header("Content-Type", "application/json")
                    .body(Body::from(serde_json::to_string(&body).unwrap()))
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::CREATED);
    }
}
```

### Integration Test with Test Database

```rust
#[cfg(test)]
mod integration {
    use sqlx::PgPool;

    #[sqlx::test(migrations = "migrations")]
    async fn test_create_and_find_merchant(pool: PgPool) {
        let repo = MerchantRepository::new(pool);

        let new_merchant = NewMerchant {
            mid: "12345".into(),
            name: "Integration Test Shop".into(),
        };

        let created = repo.create(&new_merchant).await.unwrap();
        assert!(created.id > 0);
        assert_eq!(created.mid, "12345");

        let found = repo.find_by_id(created.id).await.unwrap();
        assert!(found.is_some());
        assert_eq!(found.unwrap().name, "Integration Test Shop");
    }

    #[sqlx::test(migrations = "migrations")]
    async fn test_list_merchants_with_pagination(pool: PgPool) {
        let repo = MerchantRepository::new(pool);

        for i in 0..5 {
            repo.create(&NewMerchant {
                mid: format!("{:05}", i),
                name: format!("Shop {}", i),
            }).await.unwrap();
        }

        let (merchants, total) = repo.find_all(0, 2, None).await.unwrap();
        assert_eq!(merchants.len(), 2);
        assert_eq!(total, 5);
    }
}
```

---

## 7. Error Handling

### Error Type with IntoResponse

```rust
use axum::response::{IntoResponse, Response};
use axum::http::StatusCode;
use axum::Json;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("not found: {0}")]
    NotFound(String),

    #[error("validation error: {0}")]
    Validation(String),

    #[error("unauthorized: {0}")]
    Unauthorized(String),

    #[error("conflict: {0}")]
    Conflict(String),

    #[error("database error: {0}")]
    Database(#[from] sqlx::Error),

    #[error("internal error: {0}")]
    Internal(String),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, problem) = match &self {
            AppError::NotFound(detail) => (
                StatusCode::NOT_FOUND,
                ProblemDetail {
                    r#type: "https://api.example.com/errors/not-found".into(),
                    title: "Not Found".into(),
                    status: 404,
                    detail: detail.clone(),
                },
            ),
            AppError::Validation(detail) => (
                StatusCode::BAD_REQUEST,
                ProblemDetail {
                    r#type: "https://api.example.com/errors/validation".into(),
                    title: "Validation Error".into(),
                    status: 400,
                    detail: detail.clone(),
                },
            ),
            AppError::Unauthorized(detail) => (
                StatusCode::UNAUTHORIZED,
                ProblemDetail {
                    r#type: "https://api.example.com/errors/unauthorized".into(),
                    title: "Unauthorized".into(),
                    status: 401,
                    detail: detail.clone(),
                },
            ),
            AppError::Conflict(detail) => (
                StatusCode::CONFLICT,
                ProblemDetail {
                    r#type: "https://api.example.com/errors/conflict".into(),
                    title: "Conflict".into(),
                    status: 409,
                    detail: detail.clone(),
                },
            ),
            AppError::Database(err) => {
                tracing::error!(error = %err, "database error");
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    ProblemDetail {
                        r#type: "https://api.example.com/errors/internal".into(),
                        title: "Internal Server Error".into(),
                        status: 500,
                        detail: "An unexpected error occurred".into(),
                    },
                )
            }
            AppError::Internal(detail) => {
                tracing::error!(detail = %detail, "internal error");
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    ProblemDetail {
                        r#type: "https://api.example.com/errors/internal".into(),
                        title: "Internal Server Error".into(),
                        status: 500,
                        detail: "An unexpected error occurred".into(),
                    },
                )
            }
        };

        (status, Json(problem)).into_response()
    }
}

#[derive(Debug, serde::Serialize)]
pub struct ProblemDetail {
    pub r#type: String,
    pub title: String,
    pub status: u16,
    pub detail: String,
}
```

### Handler Return Type

```rust
// Handlers return Result<impl IntoResponse, AppError>
async fn get_merchant(
    State(state): State<AppState>,
    Path(id): Path<i64>,
) -> Result<Json<MerchantResponse>, AppError> {
    let merchant = state
        .merchant_service
        .find_by_id(id)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("merchant {} not found", id)))?;

    Ok(Json(merchant.into()))
}
```

---

## 8. Anti-Patterns (Axum-Specific)

- **`unwrap()` in handlers** — always use `?` with a proper error type implementing `IntoResponse`; `unwrap()` causes a panic that crashes the task, returning an opaque 500
- **Blocking in async handlers** — never call synchronous I/O (file reads, CPU-heavy computation) directly; use `tokio::task::spawn_blocking` to offload to a blocking thread
- **`clone()` on large State** — wrap expensive-to-clone state in `Arc`; `State` requires `Clone`, so `State<Arc<AppState>>` avoids deep copies
- **Missing error handling** — every fallible operation must propagate errors via `?`; silent `let _ =` discards errors that should be logged or returned
- **`panic!` in request handlers** — panics abort the current task and produce unhelpful responses; always return `Result<_, AppError>`
- **Body extractor not last** — `Json`, `Form`, and other body-consuming extractors must appear as the last function parameter
- **Not using `#[derive(Clone)]` on State** — `AppState` must implement `Clone` for `with_state()`; use `Arc` for fields that are expensive to clone
- **Forgetting `.await` on sqlx queries** — sqlx query builders return futures; missing `.await` silently does nothing and the query never executes
