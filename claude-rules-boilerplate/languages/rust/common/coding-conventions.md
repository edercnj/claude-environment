# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rust Coding Conventions

## Style Enforcement

- **clippy** mandatory (`cargo clippy -- -D warnings`)
- **rustfmt** for formatting (`cargo fmt`)
- Edition: latest stable (2021 or 2024)

## Naming Conventions

| Element         | Convention         | Example                    |
| --------------- | ------------------ | -------------------------- |
| Struct          | PascalCase         | `MerchantService`          |
| Enum            | PascalCase         | `TransactionStatus`        |
| Enum Variant    | PascalCase         | `Approved`, `Denied`       |
| Trait           | PascalCase         | `Repository`               |
| Function        | snake_case         | `process_order()`          |
| Variable        | snake_case         | `merchant_name`            |
| Constant        | SCREAMING_SNAKE    | `MAX_RETRY_COUNT`          |
| Static          | SCREAMING_SNAKE    | `DEFAULT_TIMEOUT`          |
| Module          | snake_case         | `merchant_service`         |
| Type Parameter  | PascalCase (short) | `T`, `E`, `Item`           |
| Lifetime        | lowercase          | `'a`, `'ctx`               |
| Macro           | snake_case!        | `vec!`, `println!`         |

## Ownership Model

Borrow by default, clone only when necessary.

```rust
// CORRECT - borrow by reference
fn process_merchant(merchant: &Merchant) -> Result<Response> {
    let masked = mask_document(&merchant.document);
    Ok(Response::new(merchant.mid.clone(), masked))
}

// CORRECT - take ownership when consuming
fn save_merchant(merchant: Merchant) -> Result<MerchantId> {
    repository.insert(merchant)
}

// FORBIDDEN - unnecessary clone
fn process(merchant: &Merchant) -> String {
    let m = merchant.clone(); // Unnecessary
    m.name
}
```

## Result and Option

```rust
// CORRECT - Result<T, E> for fallible operations
fn find_by_mid(mid: &str) -> Result<Option<Merchant>, RepositoryError> {
    let merchant = sqlx::query_as!(Merchant, "SELECT * FROM merchants WHERE mid = $1", mid)
        .fetch_optional(&pool)
        .await?;
    Ok(merchant)
}

// CORRECT - use ? operator for propagation
fn process_transaction(request: &IsoMessage) -> Result<TransactionResult, ProcessingError> {
    let amount = extract_amount(request)?;
    let decision = engine.decide(&amount)?;
    let transaction = build_transaction(request, &decision)?;
    repository.save(&transaction)?;
    Ok(build_response(request, &decision))
}

// FORBIDDEN - unwrap() in production code
let merchant = find_by_mid("MID001").unwrap(); // Never in production
```

## Derive Macros

```rust
// CORRECT - derive common traits on all types
#[derive(Debug, Clone, PartialEq)]
pub struct Merchant {
    pub id: i64,
    pub mid: String,
    pub name: String,
    pub document: String,
    pub status: MerchantStatus,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum MerchantStatus {
    Active,
    Inactive,
    Deleted,
}

// Serde for serialization
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MerchantResponse {
    pub id: i64,
    pub mid: String,
    pub name: String,
    pub document_masked: String,
    pub status: String,
    pub created_at: String,
}
```

## Error Types with thiserror

```rust
use thiserror::Error;

#[derive(Debug, Error)]
pub enum DomainError {
    #[error("Merchant not found: {mid}")]
    MerchantNotFound { mid: String },

    #[error("Merchant with MID '{mid}' already exists")]
    MerchantAlreadyExists { mid: String },

    #[error("Invalid document: {0}")]
    InvalidDocument(String),

    #[error("Processing failed: {0}")]
    ProcessingError(#[from] anyhow::Error),

    #[error("Database error")]
    DatabaseError(#[from] sqlx::Error),
}

// Usage with ? operator
fn create_merchant(request: CreateMerchantRequest) -> Result<Merchant, DomainError> {
    if repository.find_by_mid(&request.mid)?.is_some() {
        return Err(DomainError::MerchantAlreadyExists { mid: request.mid });
    }
    let merchant = Merchant::from(request);
    repository.save(&merchant)?;
    Ok(merchant)
}
```

## Display Trait

```rust
use std::fmt;

impl fmt::Display for MerchantStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            MerchantStatus::Active => write!(f, "ACTIVE"),
            MerchantStatus::Inactive => write!(f, "INACTIVE"),
            MerchantStatus::Deleted => write!(f, "DELETED"),
        }
    }
}
```

## Module Organization

```
src/
├── main.rs
├── lib.rs
├── domain/
│   ├── mod.rs
│   ├── merchant.rs
│   ├── transaction.rs
│   └── error.rs
├── adapter/
│   ├── mod.rs
│   ├── http/
│   │   ├── mod.rs
│   │   └── merchant_handler.rs
│   └── persistence/
│       ├── mod.rs
│       └── merchant_repository.rs
└── application/
    ├── mod.rs
    └── merchant_service.rs
```

## Lifetimes

Avoid explicit lifetimes when possible. Annotate when the compiler requires.

```rust
// CORRECT - lifetime elision handles this
fn first_word(s: &str) -> &str {
    &s[..s.find(' ').unwrap_or(s.len())]
}

// CORRECT - explicit when needed
struct MerchantView<'a> {
    merchant: &'a Merchant,
    terminals: &'a [Terminal],
}
```

## Anti-Patterns (FORBIDDEN)

- `unwrap()` or `expect()` in production code (use `?` or handle explicitly)
- `unsafe` blocks without documented justification
- `clone()` to satisfy the borrow checker without understanding why
- `pub` on struct fields without API design justification
- Deeply nested `match` statements (extract to functions)
- `String` where `&str` suffices as input parameter
- Ignoring clippy warnings
