# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Go Coding Conventions

## Style Enforcement

- **gofmt** mandatory (automatic formatting)
- **golangci-lint** recommended with curated linter set
- **go vet** for static analysis

## Naming Conventions

| Element            | Convention     | Example                    |
| ------------------ | -------------- | -------------------------- |
| Exported type      | PascalCase     | `MerchantService`          |
| Unexported type    | camelCase      | `merchantCache`            |
| Exported function  | PascalCase     | `ProcessOrder()`           |
| Unexported function| camelCase      | `validateInput()`          |
| Constant (exported)| PascalCase     | `MaxRetryCount`            |
| Constant (unexported)| camelCase   | `defaultTimeout`           |
| Package            | lowercase      | `merchant`                 |
| Interface          | PascalCase     | `Repository`               |
| Acronyms           | All caps       | `HTTPClient`, `SQLDB`      |

## Error Handling

Always check errors. Never ignore them.

```go
// CORRECT - wrap errors with context
func (s *MerchantService) FindByMID(ctx context.Context, mid string) (*Merchant, error) {
    merchant, err := s.repo.FindByMID(ctx, mid)
    if err != nil {
        return nil, fmt.Errorf("finding merchant by MID %s: %w", mid, err)
    }
    if merchant == nil {
        return nil, ErrMerchantNotFound
    }
    return merchant, nil
}

// FORBIDDEN - ignored error
result, _ := s.repo.FindByMID(ctx, mid)
```

### Custom Error Types

```go
type MerchantNotFoundError struct {
    MID string
}

func (e *MerchantNotFoundError) Error() string {
    return fmt.Sprintf("merchant not found: %s", e.MID)
}

// Sentinel errors for common cases
var (
    ErrMerchantNotFound = errors.New("merchant not found")
    ErrDuplicateMID     = errors.New("duplicate MID")
    ErrInvalidDocument  = errors.New("invalid document")
)

// Checking errors
if errors.Is(err, ErrMerchantNotFound) {
    // handle not found
}

var notFoundErr *MerchantNotFoundError
if errors.As(err, &notFoundErr) {
    log.Warn("Merchant not found", "mid", notFoundErr.MID)
}
```

## Interfaces

Small interfaces (1-3 methods), defined where consumed.

```go
// CORRECT - small, consumer-defined interface
type MerchantRepository interface {
    FindByMID(ctx context.Context, mid string) (*Merchant, error)
    Save(ctx context.Context, merchant *Merchant) error
}

// CORRECT - single-method interface
type Validator interface {
    Validate(ctx context.Context) error
}

// FORBIDDEN - large "god" interface
type MerchantManager interface {
    FindByMID(ctx context.Context, mid string) (*Merchant, error)
    Save(ctx context.Context, merchant *Merchant) error
    Delete(ctx context.Context, id int64) error
    ListAll(ctx context.Context) ([]*Merchant, error)
    Validate(merchant *Merchant) error
    Export(ctx context.Context, format string) ([]byte, error)
}
```

## Context Propagation

First parameter is always `ctx context.Context`.

```go
func (s *OrderService) ProcessOrder(ctx context.Context, order *Order) (*OrderResult, error) {
    merchant, err := s.merchantRepo.FindByMID(ctx, order.MerchantID)
    if err != nil {
        return nil, fmt.Errorf("finding merchant: %w", err)
    }
    return s.processor.Process(ctx, order, merchant)
}
```

## Struct Composition

```go
// CORRECT - embedding for composition
type BaseEntity struct {
    ID        int64
    CreatedAt time.Time
    UpdatedAt time.Time
}

type Merchant struct {
    BaseEntity
    MID      string
    Name     string
    Document string
    Status   MerchantStatus
}
```

## Goroutine Safety

```go
// CORRECT - channels for communication
func (s *Server) processMessages(ctx context.Context) {
    for {
        select {
        case msg := <-s.incoming:
            go s.handleMessage(ctx, msg)
        case <-ctx.Done():
            return
        }
    }
}

// CORRECT - sync.Mutex for shared state
type ConnectionManager struct {
    mu          sync.RWMutex
    connections map[string]*Connection
}

func (cm *ConnectionManager) Register(conn *Connection) {
    cm.mu.Lock()
    defer cm.mu.Unlock()
    cm.connections[conn.ID] = conn
}

func (cm *ConnectionManager) Get(id string) (*Connection, bool) {
    cm.mu.RLock()
    defer cm.mu.RUnlock()
    conn, ok := cm.connections[id]
    return conn, ok
}
```

## Package Organization

```go
// Package names: short, lowercase, singular
package merchant  // not "merchants" or "merchantService"

// One file per major type
// merchant.go        - Merchant struct and methods
// repository.go      - MerchantRepository interface
// service.go         - MerchantService
// errors.go          - Error types and sentinels
```

## Defer for Cleanup

```go
func (s *Service) ProcessFile(ctx context.Context, path string) error {
    f, err := os.Open(path)
    if err != nil {
        return fmt.Errorf("opening file: %w", err)
    }
    defer f.Close()

    return s.process(ctx, f)
}
```

## Anti-Patterns (FORBIDDEN)

- Ignoring errors with `_`
- Global mutable state
- `init()` functions (unless absolutely necessary)
- `panic()` for error handling (use error returns)
- Naked goroutines without lifecycle management
- Large interfaces (keep to 1-3 methods)
- Package names that stutter (`merchant.MerchantService`)
