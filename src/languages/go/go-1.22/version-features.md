# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Go 1.22 Version Features

## Range Over Integers

Iterate directly over integer ranges without index variables.

```go
// OLD - traditional for loop
for i := 0; i < 10; i++ {
    fmt.Println(i)
}

// NEW (1.22) - range over integers
for i := range 10 {
    fmt.Println(i) // 0, 1, 2, ..., 9
}

// Practical: retry logic
for attempt := range maxRetries {
    err := operation()
    if err == nil {
        break
    }
    log.Warn("retry", "attempt", attempt+1, "error", err)
    time.Sleep(backoff(attempt))
}

// Practical: generate test data
merchants := make([]*Merchant, 0, 100)
for i := range 100 {
    merchants = append(merchants, &Merchant{
        MID:  fmt.Sprintf("MID%015d", i),
        Name: fmt.Sprintf("Store %d", i),
    })
}
```

## Enhanced `net/http.ServeMux` with Method Patterns

The standard library `ServeMux` now supports HTTP method routing and path parameters.

```go
// OLD - manual method checking
mux := http.NewServeMux()
mux.HandleFunc("/api/v1/merchants", func(w http.ResponseWriter, r *http.Request) {
    switch r.Method {
    case http.MethodGet:
        listMerchants(w, r)
    case http.MethodPost:
        createMerchant(w, r)
    default:
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
    }
})

// NEW (1.22) - method patterns in ServeMux
mux := http.NewServeMux()
mux.HandleFunc("GET /api/v1/merchants", listMerchants)
mux.HandleFunc("POST /api/v1/merchants", createMerchant)
mux.HandleFunc("GET /api/v1/merchants/{id}", getMerchant)
mux.HandleFunc("PUT /api/v1/merchants/{id}", updateMerchant)
mux.HandleFunc("DELETE /api/v1/merchants/{id}", deleteMerchant)

// Path parameters via Request.PathValue
func getMerchant(w http.ResponseWriter, r *http.Request) {
    id := r.PathValue("id")
    merchant, err := service.FindByID(r.Context(), id)
    if err != nil {
        http.Error(w, "Not found", http.StatusNotFound)
        return
    }
    json.NewEncoder(w).Encode(merchant)
}

// Nested routes with sub-resources
mux.HandleFunc("GET /api/v1/merchants/{merchantId}/terminals", listTerminals)
mux.HandleFunc("POST /api/v1/merchants/{merchantId}/terminals", createTerminal)

func listTerminals(w http.ResponseWriter, r *http.Request) {
    merchantID := r.PathValue("merchantId")
    terminals, err := service.ListByMerchant(r.Context(), merchantID)
    // ...
}
```

### Wildcard Matching

```go
// Catch-all with trailing slash
mux.HandleFunc("GET /static/", serveStatic)

// Exact match (no trailing slash)
mux.HandleFunc("GET /api/v1/health", healthCheck)

// Precedence: more specific patterns win
mux.HandleFunc("GET /api/v1/merchants/{id}", getMerchant)       // matches /api/v1/merchants/123
mux.HandleFunc("GET /api/v1/merchants/summary", getSummary)     // matches /api/v1/merchants/summary exactly
```

## `slices` and `maps` Packages (Standard Library)

Generic utility functions for slices and maps, stabilized from `golang.org/x/exp`.

```go
import (
    "maps"
    "slices"
)

// Sorting
merchants := []Merchant{...}
slices.SortFunc(merchants, func(a, b Merchant) int {
    return strings.Compare(a.Name, b.Name)
})

// Contains
if slices.Contains(validMCCs, merchant.MCC) {
    // process
}

// Find
idx := slices.IndexFunc(merchants, func(m Merchant) bool {
    return m.MID == targetMID
})

// Compact (remove consecutive duplicates)
sorted := slices.Compact(sortedItems)

// Maps
configCopy := maps.Clone(originalConfig)
maps.DeleteFunc(cache, func(key string, value *CacheEntry) bool {
    return value.IsExpired()
})

// Collect keys/values
allMIDs := slices.Collect(maps.Keys(merchantMap))
```

## `log/slog` Structured Logging (Since 1.21)

Standard library structured logging.

```go
import "log/slog"

// Default text handler
logger := slog.Default()
logger.Info("merchant created", "mid", merchant.MID, "status", merchant.Status)

// JSON handler for production
handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
    Level: slog.LevelInfo,
})
logger = slog.New(handler)

// Grouped attributes
logger.Info("transaction processed",
    slog.Group("transaction",
        slog.String("mti", "1200"),
        slog.String("stan", "123456"),
        slog.String("rc", "00"),
    ),
    slog.Group("merchant",
        slog.String("mid", merchant.MID),
        slog.String("tid", terminal.TID),
    ),
)

// Logger with persistent context
txLogger := logger.With(
    slog.String("trace_id", traceID),
    slog.String("span_id", spanID),
)
txLogger.Info("processing started")
txLogger.Info("processing completed", "duration_ms", elapsed.Milliseconds())
```

## Loop Variable Semantics Fix

Loop variables are now per-iteration (not per-loop), fixing a long-standing gotcha.

```go
// Before 1.22 - all goroutines captured the same variable
for _, m := range merchants {
    go func() {
        process(m) // Bug: all goroutines see the last merchant
    }()
}

// Go 1.22 - each iteration gets its own variable
for _, m := range merchants {
    go func() {
        process(m) // Correct: each goroutine sees its own merchant
    }()
}
```

## Recommended go.mod (1.22)

```
module github.com/company/project

go 1.22

require (
    go.uber.org/zap v1.27.0
    github.com/stretchr/testify v1.9.0
)
```
