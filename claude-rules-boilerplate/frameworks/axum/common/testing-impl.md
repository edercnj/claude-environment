# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Axum — Testing Patterns
> Extends: `core/03-testing-philosophy.md`

## Integration Tests with tower::ServiceExt

```rust
use axum::body::Body;
use axum::http::{Request, StatusCode};
use tower::ServiceExt;

#[tokio::test]
async fn test_create_merchant_returns_201() {
    let app = create_test_app().await;

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/merchants")
                .header("Content-Type", "application/json")
                .header("X-API-Key", "test-key")
                .body(Body::from(
                    r#"{"mid":"123456789012345","name":"Test","document":"12345678000190","mcc":"5411"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::CREATED);

    let body = axum::body::to_bytes(response.into_body(), usize::MAX).await.unwrap();
    let merchant: MerchantResponse = serde_json::from_slice(&body).unwrap();
    assert_eq!(merchant.mid, "123456789012345");
}

#[tokio::test]
async fn test_get_merchant_not_found_returns_404() {
    let app = create_test_app().await;

    let response = app
        .oneshot(
            Request::builder()
                .uri("/api/v1/merchants/99999")
                .header("X-API-Key", "test-key")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::NOT_FOUND);
}
```

## Test App Setup

```rust
async fn create_test_app() -> Router {
    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect("postgres://test:test@localhost:5432/test_db")
        .await
        .expect("Failed to connect to test database");

    let state = AppState {
        merchant_service: Arc::new(MerchantService::new(pool)),
        config: Arc::new(test_config()),
    };

    create_router(state)
}

fn test_config() -> AppConfig {
    AppConfig {
        server: ServerConfig { host: "127.0.0.1".into(), port: 0 },
        database: DatabaseConfig { url: "postgres://test:test@localhost/test".into(), max_connections: 2, idle_timeout_secs: 60 },
        auth: AuthConfig { api_key: "test-key".into() },
        log: LogConfig { level: "warn".into(), format: "compact".into() },
    }
}
```

## Unit Tests for Services

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use mockall::predicate::*;

    mock! {
        pub MerchantRepo {}
        #[async_trait]
        impl MerchantRepository for MerchantRepo {
            async fn find_by_id(&self, id: i64) -> Result<Option<Merchant>, sqlx::Error>;
            async fn find_by_mid(&self, mid: &str) -> Result<Option<Merchant>, sqlx::Error>;
            async fn create(&self, merchant: &CreateMerchantRequest) -> Result<Merchant, sqlx::Error>;
        }
    }

    #[tokio::test]
    async fn find_by_mid_returns_merchant_when_exists() {
        let mut repo = MockMerchantRepo::new();
        repo.expect_find_by_mid()
            .with(eq("123"))
            .returning(|_| Ok(Some(Merchant { id: 1, mid: "123".into(), name: "Store".into(), ..Default::default() })));

        let service = MerchantService::with_repo(Arc::new(repo));
        let result = service.find_by_mid("123").await.unwrap();

        assert_eq!(result.mid, "123");
    }

    #[tokio::test]
    async fn find_by_mid_returns_error_when_not_found() {
        let mut repo = MockMerchantRepo::new();
        repo.expect_find_by_mid()
            .with(eq("unknown"))
            .returning(|_| Ok(None));

        let service = MerchantService::with_repo(Arc::new(repo));
        let result = service.find_by_mid("unknown").await;

        assert!(matches!(result, Err(AppError::NotFound(_))));
    }
}
```

## Reqwest for Full Integration Tests

```rust
#[tokio::test]
async fn test_full_merchant_lifecycle() {
    let client = reqwest::Client::new();
    let base_url = "http://localhost:8080/api/v1";

    let res = client.post(format!("{}/merchants", base_url))
        .json(&serde_json::json!({"mid":"INT123","name":"Integration","document":"12345678000190","mcc":"5411"}))
        .header("X-API-Key", "test-key")
        .send().await.unwrap();

    assert_eq!(res.status(), 201);
    let merchant: MerchantResponse = res.json().await.unwrap();

    let res = client.get(format!("{}/merchants/{}", base_url, merchant.id))
        .header("X-API-Key", "test-key")
        .send().await.unwrap();

    assert_eq!(res.status(), 200);
}
```

## Naming Convention

```
test_[function]_[scenario]_[expected]
```

Examples: `test_create_merchant_returns_201`, `test_find_by_mid_returns_error_when_not_found`

## Anti-Patterns

- Do NOT use `unwrap()` in production code -- only acceptable in tests
- Do NOT test with a shared mutable database -- isolate test data per test
- Do NOT skip error path tests -- verify all error status codes
- Do NOT forget to run `sqlx migrate run` before integration tests
