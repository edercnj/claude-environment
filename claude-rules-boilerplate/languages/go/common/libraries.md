# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Go Libraries

## Mandatory

| Library             | Purpose        | Justification                                  |
| ------------------- | -------------- | ---------------------------------------------- |
| zap or zerolog      | Logging        | Structured, high-performance, JSON output      |
| testify             | Testing        | Assertions, mocking, suite support             |

### Zap (Logging)

```go
import "go.uber.org/zap"

logger, _ := zap.NewProduction()
defer logger.Sync()

logger.Info("merchant created",
    zap.String("mid", merchant.MID),
    zap.String("status", string(merchant.Status)),
)

logger.Error("processing failed",
    zap.String("mti", mti),
    zap.String("stan", stan),
    zap.Error(err),
)
```

### Zerolog (Alternative)

```go
import "github.com/rs/zerolog/log"

log.Info().
    Str("mid", merchant.MID).
    Str("status", string(merchant.Status)).
    Msg("merchant created")

log.Error().
    Err(err).
    Str("mti", mti).
    Msg("processing failed")
```

### Testify

```go
import (
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
    "github.com/stretchr/testify/mock"
)

func TestProcess(t *testing.T) {
    result, err := service.Process(ctx, input)
    require.NoError(t, err)
    assert.Equal(t, "expected", result.Value)
    assert.NotNil(t, result.CreatedAt)
}
```

## Recommended

| Library               | Purpose          | When to Use                           |
| --------------------- | ---------------- | ------------------------------------- |
| viper                 | Configuration    | Multi-source config (env, file, flags)|
| sqlx                  | Database         | SQL with struct scanning              |
| otel                  | Observability    | OpenTelemetry traces and metrics      |
| chi                   | HTTP router      | Lightweight, stdlib-compatible        |
| gin                   | HTTP framework   | Full-featured web framework           |
| pgx                   | PostgreSQL       | Native PostgreSQL driver              |
| validator             | Validation       | Struct validation with tags           |
| golang-migrate        | DB migrations    | Database schema versioning            |
| wire                  | DI               | Compile-time dependency injection     |

### Chi (Router)

```go
import "github.com/go-chi/chi/v5"

r := chi.NewRouter()
r.Use(middleware.Logger)
r.Use(middleware.Recoverer)

r.Route("/api/v1", func(r chi.Router) {
    r.Get("/merchants", handler.ListMerchants)
    r.Post("/merchants", handler.CreateMerchant)
    r.Get("/merchants/{id}", handler.GetMerchant)
})
```

### SQLx (Database)

```go
import "github.com/jmoiron/sqlx"

type MerchantRepo struct {
    db *sqlx.DB
}

func (r *MerchantRepo) FindByMID(ctx context.Context, mid string) (*Merchant, error) {
    var m Merchant
    err := r.db.GetContext(ctx, &m, "SELECT * FROM merchants WHERE mid = $1", mid)
    if errors.Is(err, sql.ErrNoRows) {
        return nil, ErrMerchantNotFound
    }
    return &m, err
}
```

### OpenTelemetry

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
)

tracer := otel.Tracer("merchant-service")

func (s *Service) ProcessOrder(ctx context.Context, order *Order) error {
    ctx, span := tracer.Start(ctx, "ProcessOrder")
    defer span.End()

    span.SetAttributes(
        attribute.String("order.id", order.ID),
        attribute.String("merchant.mid", order.MerchantMID),
    )

    return s.processor.Process(ctx, order)
}
```

## Prohibited

| Library/Pattern | Reason                                    | Alternative               |
| --------------- | ----------------------------------------- | ------------------------- |
| `log` (stdlib)  | Unstructured, no levels, no JSON          | zap or zerolog            |
| `panic()`       | Error handling via panics is anti-pattern | Return `error`            |
| `init()`        | Hidden initialization, testing issues     | Explicit initialization   |
| `reflect`       | Performance cost, type safety loss        | Code generation or generics|
| `ioutil`        | Deprecated since Go 1.16                  | `os` and `io` packages   |

## Module Management

- Go modules (`go.mod`) mandatory
- `go.sum` MUST be committed
- Run `go mod tidy` before committing
- Use `go mod verify` in CI
- Minimum Go version specified in `go.mod`

## Security

- Run `govulncheck` regularly
- No packages with known critical vulnerabilities
- Audit dependencies with `go mod graph`
