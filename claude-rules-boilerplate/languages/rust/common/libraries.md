# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rust Libraries (Crates)

## Mandatory

| Crate    | Purpose          | Justification                                  |
| -------- | ---------------- | ---------------------------------------------- |
| serde    | Serialization    | De facto standard, derive macros, ecosystem    |
| tokio    | Async runtime    | Industry standard, mature, full-featured       |
| tracing  | Observability    | Structured logging, spans, OpenTelemetry compat|

### Serde

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MerchantResponse {
    pub id: i64,
    pub mid: String,
    pub name: String,
    pub document_masked: String,
    pub status: String,
    #[serde(with = "chrono::serde::ts_milliseconds")]
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateMerchantRequest {
    pub mid: String,
    pub name: String,
    pub document: String,
    pub mcc: String,
    #[serde(default)]
    pub timeout_enabled: bool,
}
```

### Tokio

```rust
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let listener = TcpListener::bind("0.0.0.0:8583").await?;

    loop {
        let (socket, addr) = listener.accept().await?;
        tokio::spawn(async move {
            if let Err(e) = handle_connection(socket).await {
                tracing::error!(%addr, error = %e, "Connection error");
            }
        });
    }
}
```

### Tracing

```rust
use tracing::{info, error, instrument, span, Level};

#[instrument(skip(repository), fields(merchant.mid = %mid))]
pub async fn find_merchant(
    mid: &str,
    repository: &dyn MerchantRepository,
) -> Result<Option<Merchant>, DomainError> {
    info!("Looking up merchant");
    let result = repository.find_by_mid(mid).await?;
    match &result {
        Some(m) => info!(status = %m.status, "Merchant found"),
        None => info!("Merchant not found"),
    }
    Ok(result)
}

// Subscriber setup
use tracing_subscriber::{fmt, EnvFilter};

fn init_tracing() {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .json()
        .init();
}
```

## Recommended

| Crate           | Purpose          | When to Use                             |
| --------------- | ---------------- | --------------------------------------- |
| anyhow          | Error handling   | Application-level error propagation     |
| thiserror       | Error types      | Library-level custom error types        |
| sqlx            | Database         | Async PostgreSQL/SQLite with compile-time checks |
| reqwest         | HTTP client      | External API calls                      |
| axum            | HTTP framework   | Web APIs (Tower-based, Tokio ecosystem) |
| clap            | CLI parsing      | Command-line argument parsing           |
| config          | Configuration    | Multi-source configuration              |
| uuid            | UUIDs            | Unique identifier generation            |
| chrono          | Date/time        | Date and time operations                |

### Axum (HTTP Framework)

```rust
use axum::{routing::{get, post}, Router, Json, extract::Path};

pub fn merchant_routes() -> Router<AppState> {
    Router::new()
        .route("/api/v1/merchants", get(list_merchants).post(create_merchant))
        .route("/api/v1/merchants/:id", get(get_merchant).put(update_merchant))
}

async fn create_merchant(
    State(state): State<AppState>,
    Json(request): Json<CreateMerchantRequest>,
) -> Result<(StatusCode, Json<MerchantResponse>), AppError> {
    let merchant = state.service.create(request).await?;
    Ok((StatusCode::CREATED, Json(merchant.into())))
}
```

### SQLx (Database)

```rust
use sqlx::PgPool;

pub async fn find_by_mid(pool: &PgPool, mid: &str) -> Result<Option<Merchant>, sqlx::Error> {
    sqlx::query_as!(
        Merchant,
        "SELECT id, mid, name, document, status, created_at FROM merchants WHERE mid = $1",
        mid
    )
    .fetch_optional(pool)
    .await
}
```

### Thiserror + Anyhow

```rust
// Library code: thiserror for precise error types
#[derive(Debug, thiserror::Error)]
pub enum DomainError {
    #[error("Merchant not found: {0}")]
    NotFound(String),
    #[error("Duplicate MID: {0}")]
    Duplicate(String),
    #[error("Database error")]
    Database(#[from] sqlx::Error),
}

// Application code: anyhow for ergonomic error handling
use anyhow::{Context, Result};

async fn run() -> Result<()> {
    let pool = PgPool::connect(&db_url)
        .await
        .context("Failed to connect to database")?;
    Ok(())
}
```

## Prohibited

| Crate/Pattern     | Reason                                    | Alternative              |
| ----------------- | ----------------------------------------- | ------------------------ |
| `unsafe` blocks   | Memory safety risk without justification  | Safe abstractions        |
| `unwrap()`        | Panics in production                      | `?` operator, `expect()` in tests only |
| `println!`        | Unstructured output                       | tracing crate            |
| `log` crate       | Less capable than tracing                 | tracing                  |
| `actix-web`       | Actor model complexity for most use cases | axum                     |

## Cargo.toml Best Practices

```toml
[package]
name = "authorizer-simulator"
version = "0.1.0"
edition = "2021"
rust-version = "1.75"

[dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tokio = { version = "1", features = ["full"] }
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["json", "env-filter"] }
axum = "0.7"
sqlx = { version = "0.8", features = ["runtime-tokio", "postgres", "chrono"] }
thiserror = "2"

[dev-dependencies]
proptest = "1"
mockall = "0.13"
tokio = { version = "1", features = ["test-util"] }

[profile.release]
lto = true
strip = true
codegen-units = 1
```

## Security

- Run `cargo audit` regularly
- Pin dependencies via `Cargo.lock` (commit to repository)
- Minimize `unsafe` usage (document every instance)
- Use `#![forbid(unsafe_code)]` at crate level when possible
