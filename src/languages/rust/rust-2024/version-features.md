# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rust 2024 Edition Features

## Edition 2024

Set in `Cargo.toml`:

```toml
[package]
edition = "2024"
```

### Key Changes from Edition 2021

- `unsafe_op_in_unsafe_fn` lint is now `deny` by default
- Lifetime capture rules in opaque types (RPIT) changed
- `gen` keyword reserved
- `unsafe_attributes` requires `unsafe(...)` syntax
- Temporary lifetime extension changes

## Improved Async Traits (RPITIT)

Return Position Impl Trait in Trait (RPITIT) allows traits to have async methods without `#[async_trait]`.

```rust
// OLD - required async_trait macro
#[async_trait]
pub trait MerchantRepository {
    async fn find_by_mid(&self, mid: &str) -> Result<Option<Merchant>, RepositoryError>;
    async fn save(&self, merchant: &Merchant) -> Result<(), RepositoryError>;
}

// NEW - native async in traits (stable since 1.75, improved in 2024)
pub trait MerchantRepository {
    fn find_by_mid(&self, mid: &str) -> impl Future<Output = Result<Option<Merchant>, RepositoryError>> + Send;
    fn save(&self, merchant: &Merchant) -> impl Future<Output = Result<(), RepositoryError>> + Send;
}

// Or with async fn in traits (stable since 1.75)
pub trait MerchantRepository: Send + Sync {
    async fn find_by_mid(&self, mid: &str) -> Result<Option<Merchant>, RepositoryError>;
    async fn save(&self, merchant: &Merchant) -> Result<(), RepositoryError>;
    async fn delete(&self, id: i64) -> Result<(), RepositoryError>;
}

// Implementation
struct PostgresMerchantRepository {
    pool: PgPool,
}

impl MerchantRepository for PostgresMerchantRepository {
    async fn find_by_mid(&self, mid: &str) -> Result<Option<Merchant>, RepositoryError> {
        sqlx::query_as!(Merchant, "SELECT * FROM merchants WHERE mid = $1", mid)
            .fetch_optional(&self.pool)
            .await
            .map_err(RepositoryError::from)
    }

    async fn save(&self, merchant: &Merchant) -> Result<(), RepositoryError> {
        sqlx::query!(
            "INSERT INTO merchants (mid, name, document, status) VALUES ($1, $2, $3, $4)",
            merchant.mid, merchant.name, merchant.document, merchant.status.as_str()
        )
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn delete(&self, id: i64) -> Result<(), RepositoryError> {
        sqlx::query!("DELETE FROM merchants WHERE id = $1", id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }
}
```

## `gen` Blocks for Generators

Create iterators using generator syntax (nightly/future stable).

```rust
// gen blocks produce iterators
fn fibonacci() -> impl Iterator<Item = u64> {
    gen {
        let (mut a, mut b) = (0u64, 1u64);
        loop {
            yield a;
            (a, b) = (b, a + b);
        }
    }
}

// Practical: paginated database results
fn fetch_all_merchants(pool: &PgPool) -> impl Iterator<Item = Result<Merchant, Error>> + '_ {
    gen {
        let mut offset = 0;
        let limit = 100;
        loop {
            let batch = sqlx::query_as!(
                Merchant,
                "SELECT * FROM merchants ORDER BY id LIMIT $1 OFFSET $2",
                limit, offset
            )
            .fetch_all(pool)
            .await;

            match batch {
                Ok(merchants) if merchants.is_empty() => break,
                Ok(merchants) => {
                    for m in merchants {
                        yield Ok(m);
                    }
                    offset += limit;
                }
                Err(e) => {
                    yield Err(e.into());
                    break;
                }
            }
        }
    }
}

// Usage
for merchant in fibonacci().take(10) {
    println!("{merchant}");
}
```

## Improved let-else Patterns

Enhanced pattern matching in `let-else` statements.

```rust
// let-else for early returns on pattern failure
fn process_message(raw: &[u8]) -> Result<Response, ProcessingError> {
    let Some(mti) = extract_mti(raw) else {
        return Err(ProcessingError::InvalidMti);
    };

    let Ok(amount) = extract_amount(raw) else {
        return Err(ProcessingError::InvalidAmount);
    };

    // Destructuring with let-else
    let TransactionResult::Approved { auth_code, .. } = engine.decide(&amount) else {
        return Ok(Response::denied("51"));
    };

    Ok(Response::approved(auth_code))
}

// Combining with if-let chains
fn validate_merchant(input: &str) -> Result<Merchant, ValidationError> {
    let Some(merchant) = repository.find_by_mid(input) else {
        return Err(ValidationError::NotFound(input.to_string()));
    };

    let MerchantStatus::Active = merchant.status else {
        return Err(ValidationError::Inactive(merchant.mid.clone()));
    };

    Ok(merchant)
}
```

## Better Error Messages

The compiler provides increasingly helpful diagnostics.

```rust
// Borrow checker errors now suggest fixes
// error[E0502]: cannot borrow `items` as mutable because it is also borrowed as immutable
//   --> src/main.rs:5:5
//   |
// 4 | let first = &items[0];
//   |              ----- immutable borrow occurs here
// 5 | items.push(42);
//   | ^^^^^^^^^^^^^^ mutable borrow occurs here
// 6 | println!("{first}");
//   |           ----- immutable borrow later used here
//   |
//   = help: consider cloning `items[0]` to avoid the borrow conflict

// Trait bound errors show what's missing
// error[E0277]: `MyStruct` doesn't implement `Debug`
//   |
//   = help: the trait `Debug` is not implemented for `MyStruct`
//   = help: add `#[derive(Debug)]` to `MyStruct`
```

## Precise Capturing in RPIT (Edition 2024)

```rust
// Edition 2024 changes how lifetimes are captured in opaque types
// use<> syntax for precise capturing

fn create_handler<'a>(config: &'a Config) -> impl Fn(&str) -> Result<(), Error> + use<'a> {
    move |input| {
        validate(input, config)?;
        Ok(())
    }
}
```

## Recommended Cargo.toml (Edition 2024)

```toml
[package]
name = "authorizer-simulator"
version = "0.1.0"
edition = "2024"
rust-version = "1.85"

[dependencies]
serde = { version = "1", features = ["derive"] }
tokio = { version = "1", features = ["full"] }
tracing = "0.1"
axum = "0.8"
sqlx = { version = "0.8", features = ["runtime-tokio", "postgres"] }
thiserror = "2"

[lints.rust]
unsafe_code = "forbid"

[lints.clippy]
all = { level = "deny", priority = -1 }
pedantic = { level = "warn", priority = -1 }
```
