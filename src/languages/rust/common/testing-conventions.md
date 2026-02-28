# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rust Testing Conventions

## Framework

- **`#[test]`** attribute (standard library)
- **`assert!`**, **`assert_eq!`**, **`assert_ne!`** macros
- **proptest** for property-based testing
- **mockall** for mocking traits

## Coverage

- **cargo-tarpaulin** or **llvm-cov** for coverage measurement
- Target: >= 95% line coverage, >= 90% branch coverage

## Naming Convention

```
test_{function}_{scenario}_{expected}
```

```rust
#[test]
fn test_find_by_mid_existing_merchant_returns_some() { ... }

#[test]
fn test_find_by_mid_nonexistent_returns_none() { ... }

#[test]
fn test_create_merchant_duplicate_mid_returns_error() { ... }
```

## Unit Tests (Inline Module)

```rust
// src/domain/merchant.rs
pub struct Merchant {
    pub mid: String,
    pub name: String,
    pub status: MerchantStatus,
}

impl Merchant {
    pub fn is_active(&self) -> bool {
        self.status == MerchantStatus::Active
    }

    pub fn deactivate(&mut self) {
        self.status = MerchantStatus::Inactive;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_merchant() -> Merchant {
        Merchant {
            mid: "MID000000000001".to_string(),
            name: "Test Store".to_string(),
            status: MerchantStatus::Active,
        }
    }

    #[test]
    fn test_is_active_active_merchant_returns_true() {
        let merchant = sample_merchant();
        assert!(merchant.is_active());
    }

    #[test]
    fn test_deactivate_active_merchant_becomes_inactive() {
        let mut merchant = sample_merchant();
        merchant.deactivate();
        assert_eq!(merchant.status, MerchantStatus::Inactive);
        assert!(!merchant.is_active());
    }
}
```

## Table-Driven Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cents_decision_engine_various_amounts() {
        let engine = CentsDecisionEngine::new();

        let cases = vec![
            ("100.00", "00", "approved"),
            ("100.51", "51", "insufficient funds"),
            ("100.05", "05", "generic error"),
            ("100.14", "14", "invalid card"),
            ("100.43", "43", "stolen card"),
            ("100.96", "96", "system error"),
        ];

        for (amount, expected_rc, description) in cases {
            let amount = Decimal::from_str(amount).unwrap();
            let result = engine.decide(&amount);
            assert_eq!(
                result.response_code, expected_rc,
                "Failed for {description}: amount={amount}, expected RC={expected_rc}"
            );
        }
    }
}
```

## Integration Tests

```rust
// tests/merchant_api_test.rs
use axum::http::StatusCode;
use axum_test::TestServer;

#[tokio::test]
async fn test_create_merchant_valid_payload_returns_201() {
    let app = create_test_app().await;
    let server = TestServer::new(app).unwrap();

    let response = server
        .post("/api/v1/merchants")
        .json(&json!({
            "mid": "MID000000000001",
            "name": "Test Store",
            "document": "12345678000190",
            "mcc": "5411"
        }))
        .await;

    assert_eq!(response.status_code(), StatusCode::CREATED);
    let body: MerchantResponse = response.json();
    assert_eq!(body.mid, "MID000000000001");
}

#[tokio::test]
async fn test_get_merchant_nonexistent_returns_404() {
    let app = create_test_app().await;
    let server = TestServer::new(app).unwrap();

    let response = server.get("/api/v1/merchants/99999").await;

    assert_eq!(response.status_code(), StatusCode::NOT_FOUND);
}
```

## Property-Based Testing (Proptest)

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn test_mask_document_always_masks_middle(document in "[0-9]{11,14}") {
        let masked = mask_document(&document);
        assert!(masked.contains("****"));
        assert_eq!(masked.len(), document.len());
        assert_eq!(&masked[..3], &document[..3]);
        assert_eq!(&masked[masked.len()-2..], &document[document.len()-2..]);
    }

    #[test]
    fn test_amount_to_cents_roundtrip(cents in 0i64..1_000_000_000) {
        let amount = AmountCents(cents);
        let decimal = amount.to_decimal();
        let back = AmountCents::from_decimal(&decimal);
        assert_eq!(amount, back);
    }
}
```

## Mocking with Mockall

```rust
use mockall::automock;

#[automock]
pub trait MerchantRepository {
    fn find_by_mid(&self, mid: &str) -> Result<Option<Merchant>, RepositoryError>;
    fn save(&self, merchant: &Merchant) -> Result<(), RepositoryError>;
}

#[test]
fn test_create_merchant_saves_to_repository() {
    let mut mock_repo = MockMerchantRepository::new();

    mock_repo
        .expect_find_by_mid()
        .with(eq("MID001"))
        .returning(|_| Ok(None));

    mock_repo
        .expect_save()
        .times(1)
        .returning(|_| Ok(()));

    let service = MerchantService::new(Box::new(mock_repo));
    let result = service.create(create_request("MID001"));

    assert!(result.is_ok());
}
```

## Async Testing

```rust
#[tokio::test]
async fn test_process_transaction_approved() {
    let engine = CentsDecisionEngine::new();
    let repo = InMemoryRepository::new();
    let service = TransactionService::new(engine, repo);

    let request = sample_iso_message("100.00");
    let result = service.process(&request).await;

    assert!(result.is_ok());
    let response = result.unwrap();
    assert_eq!(response.response_code, "00");
}
```

## Test Helpers

```rust
// tests/common/mod.rs
pub fn sample_merchant(mid: &str) -> Merchant {
    Merchant {
        id: 1,
        mid: mid.to_string(),
        name: "Test Store".to_string(),
        document: "12345678000190".to_string(),
        status: MerchantStatus::Active,
        created_at: Utc::now(),
    }
}

pub async fn create_test_app() -> Router {
    let pool = setup_test_db().await;
    create_app(pool)
}
```

## Anti-Patterns

- `unwrap()` in test setup without `.expect("reason")`
- Tests without descriptive assertion messages
- Shared mutable state between tests
- Ignoring `#[should_panic]` in favor of `Result`-based tests
- Tests that depend on file system or network without mocking
- Using `println!` for debugging instead of `dbg!`
