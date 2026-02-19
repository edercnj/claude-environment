# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Axum — Configuration Patterns

## Config Crate with Serde

```rust
use config::{Config, Environment, File};
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
    #[serde(default = "default_host")]
    pub host: String,
    #[serde(default = "default_port")]
    pub port: u16,
}

#[derive(Debug, Deserialize, Clone)]
pub struct DatabaseConfig {
    pub url: String,
    #[serde(default = "default_pool_size")]
    pub max_connections: u32,
    #[serde(default = "default_idle_timeout")]
    pub idle_timeout_secs: u64,
}

#[derive(Debug, Deserialize, Clone)]
pub struct AuthConfig {
    pub api_key: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct LogConfig {
    #[serde(default = "default_log_level")]
    pub level: String,
    #[serde(default = "default_log_format")]
    pub format: String,
}

fn default_host() -> String { "0.0.0.0".into() }
fn default_port() -> u16 { 8080 }
fn default_pool_size() -> u32 { 10 }
fn default_idle_timeout() -> u64 { 300 }
fn default_log_level() -> String { "info".into() }
fn default_log_format() -> String { "json".into() }
```

## Loading Configuration

```rust
impl AppConfig {
    pub fn load() -> Result<Self, config::ConfigError> {
        let env = std::env::var("APP_ENV").unwrap_or_else(|_| "development".into());

        let config = Config::builder()
            .add_source(File::with_name("config/default"))
            .add_source(File::with_name(&format!("config/{}", env)).required(false))
            .add_source(Environment::with_prefix("APP").separator("__"))
            .build()?;

        config.try_deserialize()
    }
}
```

## TOML Config File

```toml
# config/default.toml
[server]
host = "0.0.0.0"
port = 8080

[database]
url = "postgres://simulator:simulator@localhost:5432/simulator"
max_connections = 10
idle_timeout_secs = 300

[auth]
api_key = "dev-key-1234567890123456"

[log]
level = "info"
format = "json"
```

## Environment Variable Override

Environment variables override config files with `APP__` prefix and `__` separator:

| Config Key              | Env Variable              | Default                         |
| ----------------------- | ------------------------- | ------------------------------- |
| server.port             | APP__SERVER__PORT          | 8080                            |
| database.url            | APP__DATABASE__URL         | postgres://localhost/simulator  |
| auth.api_key            | APP__AUTH__API_KEY         | (required)                      |
| log.level               | APP__LOG__LEVEL            | info                            |

## Usage in main.rs

```rust
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let config = AppConfig::load()?;

    tracing_subscriber::fmt()
        .with_env_filter(&config.log.level)
        .json()
        .init();

    let pool = PgPoolOptions::new()
        .max_connections(config.database.max_connections)
        .connect(&config.database.url)
        .await?;

    let state = AppState {
        merchant_service: Arc::new(MerchantService::new(pool.clone())),
        config: Arc::new(config.clone()),
    };

    let app = create_router(state);
    let addr = format!("{}:{}", config.server.host, config.server.port);
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    tracing::info!("listening on {}", addr);
    axum::serve(listener, app).await?;

    Ok(())
}
```

## Anti-Patterns

- Do NOT scatter `std::env::var()` calls throughout the codebase -- centralize in AppConfig
- Do NOT use `unwrap()` on config loading -- propagate errors
- Do NOT commit config files with real secrets -- use environment variables
- Do NOT skip serde defaults -- always provide sensible defaults for optional fields
