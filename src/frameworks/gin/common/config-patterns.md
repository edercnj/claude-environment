# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Gin — Configuration Patterns
> Extends: `core/10-infrastructure-principles.md`

## Viper Setup

```go
package config

import (
    "github.com/spf13/viper"
    "log/slog"
)

type Config struct {
    Server   ServerConfig   `mapstructure:"server"`
    Database DatabaseConfig `mapstructure:"database"`
    Auth     AuthConfig     `mapstructure:"auth"`
    Log      LogConfig      `mapstructure:"log"`
}

type ServerConfig struct {
    Port         int    `mapstructure:"port"`
    Host         string `mapstructure:"host"`
    ReadTimeout  int    `mapstructure:"read_timeout"`
    WriteTimeout int    `mapstructure:"write_timeout"`
}

type DatabaseConfig struct {
    URL          string `mapstructure:"url"`
    MaxOpenConns int    `mapstructure:"max_open_conns"`
    MaxIdleConns int    `mapstructure:"max_idle_conns"`
}

type AuthConfig struct {
    APIKey string `mapstructure:"api_key"`
}

type LogConfig struct {
    Level  string `mapstructure:"level"`
    Format string `mapstructure:"format"`
}

func Load() (*Config, error) {
    viper.SetConfigName("config")
    viper.SetConfigType("yaml")
    viper.AddConfigPath(".")
    viper.AddConfigPath("./config")

    viper.AutomaticEnv()
    viper.SetEnvPrefix("APP")

    setDefaults()

    if err := viper.ReadInConfig(); err != nil {
        slog.Warn("config file not found, using defaults and env vars", "error", err)
    }

    var cfg Config
    if err := viper.Unmarshal(&cfg); err != nil {
        return nil, fmt.Errorf("failed to unmarshal config: %w", err)
    }
    return &cfg, nil
}

func setDefaults() {
    viper.SetDefault("server.port", 8080)
    viper.SetDefault("server.host", "0.0.0.0")
    viper.SetDefault("server.read_timeout", 30)
    viper.SetDefault("server.write_timeout", 30)
    viper.SetDefault("database.max_open_conns", 25)
    viper.SetDefault("database.max_idle_conns", 5)
    viper.SetDefault("log.level", "info")
    viper.SetDefault("log.format", "json")
}
```

## YAML Config File

```yaml
# config.yaml
server:
  port: 8080
  host: "0.0.0.0"
  read_timeout: 30
  write_timeout: 30

database:
  url: "postgres://simulator:simulator@localhost:5432/simulator?sslmode=disable"
  max_open_conns: 25
  max_idle_conns: 5

auth:
  api_key: "${APP_API_KEY}"

log:
  level: "info"
  format: "json"
```

## Environment Variable Override

| YAML Key           | Env Variable           | Default       |
| ------------------ | ---------------------- | ------------- |
| server.port        | APP_SERVER_PORT        | 8080          |
| database.url       | APP_DATABASE_URL       | (required)    |
| auth.api_key       | APP_AUTH_API_KEY       | (required)    |
| log.level          | APP_LOG_LEVEL          | info          |

## Usage in main.go

```go
func main() {
    cfg, err := config.Load()
    if err != nil {
        slog.Error("failed to load config", "error", err)
        os.Exit(1)
    }

    r := gin.New()
    r.Run(fmt.Sprintf("%s:%d", cfg.Server.Host, cfg.Server.Port))
}
```

## Anti-Patterns

- Do NOT scatter `os.Getenv()` calls throughout the codebase -- centralize in config
- Do NOT skip defaults for optional configuration
- Do NOT commit config files with real secrets -- use environment variables
- Do NOT use untyped `viper.Get()` -- unmarshal into typed structs
