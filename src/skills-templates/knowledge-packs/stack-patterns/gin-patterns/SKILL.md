---
name: gin-patterns
description: "Gin-specific patterns: middleware chains, gin.Context, go-playground/validator, GORM/sqlx data access, viper config, httptest testing, centralized error handling. Internal reference for agents producing Gin code."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Gin Patterns

## Purpose

Provides Gin-specific implementation patterns that supplement the generic layer templates. Agents reference this pack when generating code for a Go + Gin project.

---

## 1. Middleware Chain

### Gin Middleware Signature

All middleware uses `gin.HandlerFunc` — a function taking `*gin.Context`.

```go
func AuthMiddleware(authService AuthService) gin.HandlerFunc {
    return func(c *gin.Context) {
        token := c.GetHeader("Authorization")
        if token == "" {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
                "error": "missing authorization header",
            })
            return // always return after Abort
        }

        claims, err := authService.ValidateToken(token)
        if err != nil {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
                "error": "invalid token",
            })
            return
        }

        c.Set("userID", claims.UserID)
        c.Next() // proceed to next handler
    }
}
```

### Recovery Middleware

```go
func RecoveryMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        defer func() {
            if r := recover(); r != nil {
                log.Printf("panic recovered: %v\n%s", r, debug.Stack())
                c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{
                    "error": "internal server error",
                })
            }
        }()
        c.Next()
    }
}
```

### Logging Middleware

```go
func LoggingMiddleware(logger *slog.Logger) gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()

        c.Next()

        logger.Info("request completed",
            "method", c.Request.Method,
            "path", c.Request.URL.Path,
            "status", c.Writer.Status(),
            "duration", time.Since(start),
            "client_ip", c.ClientIP(),
        )
    }
}
```

### Handler Groups

```go
func SetupRouter(
    authService AuthService,
    logger *slog.Logger,
    merchantHandler *MerchantHandler,
    healthHandler *HealthHandler,
) *gin.Engine {
    r := gin.New() // use New() instead of Default() for custom middleware
    r.Use(RecoveryMiddleware())
    r.Use(LoggingMiddleware(logger))

    // Public routes
    public := r.Group("/api/v1")
    {
        public.GET("/health", healthHandler.Health)
    }

    // Protected routes
    protected := r.Group("/api/v1")
    protected.Use(AuthMiddleware(authService))
    {
        protected.GET("/merchants", merchantHandler.List)
        protected.POST("/merchants", merchantHandler.Create)
        protected.GET("/merchants/:id", merchantHandler.GetByID)
        protected.DELETE("/merchants/:id", merchantHandler.Delete)
    }

    return r
}
```

---

## 2. Request Handling

### Binding JSON and Query Parameters

```go
type CreateMerchantRequest struct {
    MID  string `json:"mid"  binding:"required,max=15"`
    Name string `json:"name" binding:"required,max=100"`
    Type string `json:"type" binding:"required,oneof=physical online"`
}

type ListMerchantsQuery struct {
    Page   int    `form:"page"   binding:"min=0"`
    Limit  int    `form:"limit"  binding:"min=1,max=100"`
    Status string `form:"status" binding:"omitempty,oneof=active inactive"`
}

func (h *MerchantHandler) Create(c *gin.Context) {
    var req CreateMerchantRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{
            "error":   "validation failed",
            "details": formatValidationErrors(err),
        })
        return
    }

    merchant, err := h.service.Create(c.Request.Context(), req.MID, req.Name, req.Type)
    if err != nil {
        _ = c.Error(err) // attach to context for error middleware
        return
    }

    c.JSON(http.StatusCreated, toMerchantResponse(merchant))
}

func (h *MerchantHandler) List(c *gin.Context) {
    var q ListMerchantsQuery
    q.Limit = 20 // default before binding
    if err := c.ShouldBindQuery(&q); err != nil {
        c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{
            "error": "invalid query parameters",
        })
        return
    }

    merchants, total, err := h.service.List(c.Request.Context(), q.Page, q.Limit, q.Status)
    if err != nil {
        _ = c.Error(err)
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "data":  toMerchantResponses(merchants),
        "total": total,
        "page":  q.Page,
        "limit": q.Limit,
    })
}
```

### Custom Validators (go-playground/validator)

```go
func RegisterCustomValidators(v *validator.Validate) {
    _ = v.RegisterValidation("mid_format", func(fl validator.FieldLevel) bool {
        mid := fl.Field().String()
        matched, _ := regexp.MatchString(`^\d{1,15}$`, mid)
        return matched
    })
}

// Register with Gin
func init() {
    if v, ok := binding.Validator.Engine().(*validator.Validate); ok {
        RegisterCustomValidators(v)
    }
}
```

### Path Parameter Handling

```go
func (h *MerchantHandler) GetByID(c *gin.Context) {
    idStr := c.Param("id")
    id, err := strconv.ParseInt(idStr, 10, 64)
    if err != nil {
        c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{
            "error": "invalid merchant ID",
        })
        return
    }

    merchant, err := h.service.FindByID(c.Request.Context(), id)
    if err != nil {
        _ = c.Error(err)
        return
    }

    c.JSON(http.StatusOK, toMerchantResponse(merchant))
}
```

---

## 3. Data Access

### Repository Interface (Domain Layer)

```go
type MerchantRepository interface {
    FindByID(ctx context.Context, id int64) (*Merchant, error)
    FindAll(ctx context.Context, page, limit int, status string) ([]*Merchant, int64, error)
    Create(ctx context.Context, merchant *Merchant) (*Merchant, error)
    Update(ctx context.Context, merchant *Merchant) error
    Delete(ctx context.Context, id int64) error
}
```

### Implementation with sqlx

```go
type merchantRepo struct {
    db *sqlx.DB
}

func NewMerchantRepository(db *sqlx.DB) MerchantRepository {
    return &merchantRepo{db: db}
}

func (r *merchantRepo) FindByID(ctx context.Context, id int64) (*Merchant, error) {
    var m Merchant
    err := r.db.GetContext(ctx, &m,
        "SELECT id, mid, name, status, created_at, updated_at FROM merchants WHERE id = $1", id)
    if errors.Is(err, sql.ErrNoRows) {
        return nil, ErrMerchantNotFound
    }
    return &m, err
}

func (r *merchantRepo) FindAll(ctx context.Context, page, limit int, status string) ([]*Merchant, int64, error) {
    var total int64
    countQuery := "SELECT COUNT(*) FROM merchants WHERE ($1 = '' OR status = $1)"
    if err := r.db.GetContext(ctx, &total, countQuery, status); err != nil {
        return nil, 0, fmt.Errorf("counting merchants: %w", err)
    }

    var merchants []*Merchant
    query := `SELECT id, mid, name, status, created_at, updated_at
              FROM merchants WHERE ($1 = '' OR status = $1)
              ORDER BY created_at DESC LIMIT $2 OFFSET $3`
    if err := r.db.SelectContext(ctx, &merchants, query, status, limit, page*limit); err != nil {
        return nil, 0, fmt.Errorf("listing merchants: %w", err)
    }

    return merchants, total, nil
}
```

### Connection Pooling

```go
func NewDB(cfg DatabaseConfig) (*sqlx.DB, error) {
    db, err := sqlx.Connect("postgres", cfg.DSN)
    if err != nil {
        return nil, fmt.Errorf("connecting to database: %w", err)
    }

    db.SetMaxOpenConns(cfg.MaxOpenConns)       // e.g., 25
    db.SetMaxIdleConns(cfg.MaxIdleConns)       // e.g., 5
    db.SetConnMaxLifetime(cfg.ConnMaxLifetime) // e.g., 5 * time.Minute
    db.SetConnMaxIdleTime(cfg.ConnMaxIdleTime) // e.g., 1 * time.Minute

    return db, nil
}
```

### Transaction Management

```go
func (r *merchantRepo) CreateWithAudit(ctx context.Context, merchant *Merchant) (*Merchant, error) {
    tx, err := r.db.BeginTxx(ctx, nil)
    if err != nil {
        return nil, fmt.Errorf("beginning transaction: %w", err)
    }
    defer func() {
        if err != nil {
            _ = tx.Rollback()
        }
    }()

    var id int64
    err = tx.QueryRowxContext(ctx,
        `INSERT INTO merchants (mid, name, status, created_at, updated_at)
         VALUES ($1, $2, $3, NOW(), NOW()) RETURNING id`,
        merchant.MID, merchant.Name, merchant.Status,
    ).Scan(&id)
    if err != nil {
        return nil, fmt.Errorf("inserting merchant: %w", err)
    }

    _, err = tx.ExecContext(ctx,
        `INSERT INTO audit_log (entity_type, entity_id, action, created_at)
         VALUES ('merchant', $1, 'create', NOW())`, id)
    if err != nil {
        return nil, fmt.Errorf("inserting audit log: %w", err)
    }

    if err = tx.Commit(); err != nil {
        return nil, fmt.Errorf("committing transaction: %w", err)
    }

    merchant.ID = id
    return merchant, nil
}
```

### GORM Alternative

```go
type merchantGormRepo struct {
    db *gorm.DB
}

func (r *merchantGormRepo) FindByID(ctx context.Context, id int64) (*Merchant, error) {
    var m Merchant
    result := r.db.WithContext(ctx).First(&m, id)
    if errors.Is(result.Error, gorm.ErrRecordNotFound) {
        return nil, ErrMerchantNotFound
    }
    return &m, result.Error
}

func (r *merchantGormRepo) Create(ctx context.Context, merchant *Merchant) (*Merchant, error) {
    result := r.db.WithContext(ctx).Create(merchant)
    return merchant, result.Error
}
```

---

## 4. Configuration

### Viper-Based Config Loading

```go
type Config struct {
    Server   ServerConfig   `mapstructure:"server"`
    Database DatabaseConfig `mapstructure:"database"`
    Auth     AuthConfig     `mapstructure:"auth"`
    Log      LogConfig      `mapstructure:"log"`
}

type ServerConfig struct {
    Port         int           `mapstructure:"port"`
    ReadTimeout  time.Duration `mapstructure:"read_timeout"`
    WriteTimeout time.Duration `mapstructure:"write_timeout"`
}

type DatabaseConfig struct {
    DSN             string        `mapstructure:"dsn"`
    MaxOpenConns    int           `mapstructure:"max_open_conns"`
    MaxIdleConns    int           `mapstructure:"max_idle_conns"`
    ConnMaxLifetime time.Duration `mapstructure:"conn_max_lifetime"`
    ConnMaxIdleTime time.Duration `mapstructure:"conn_max_idle_time"`
}

func LoadConfig(path string) (*Config, error) {
    viper.SetConfigFile(path)
    viper.SetConfigType("yaml")

    // Environment variable overrides (APP_SERVER_PORT -> server.port)
    viper.SetEnvPrefix("APP")
    viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
    viper.AutomaticEnv()

    // Defaults
    viper.SetDefault("server.port", 8080)
    viper.SetDefault("server.read_timeout", 10*time.Second)
    viper.SetDefault("server.write_timeout", 10*time.Second)
    viper.SetDefault("database.max_open_conns", 25)
    viper.SetDefault("database.max_idle_conns", 5)

    if err := viper.ReadInConfig(); err != nil {
        return nil, fmt.Errorf("reading config: %w", err)
    }

    var cfg Config
    if err := viper.Unmarshal(&cfg); err != nil {
        return nil, fmt.Errorf("unmarshaling config: %w", err)
    }

    return &cfg, nil
}
```

### envconfig Alternative (Struct-Based)

```go
type Config struct {
    Port        int    `envconfig:"PORT"         default:"8080"`
    DatabaseDSN string `envconfig:"DATABASE_DSN" required:"true"`
    LogLevel    string `envconfig:"LOG_LEVEL"    default:"info"`
    JWTSecret   string `envconfig:"JWT_SECRET"   required:"true"`
}

func LoadFromEnv() (*Config, error) {
    var cfg Config
    if err := envconfig.Process("APP", &cfg); err != nil {
        return nil, fmt.Errorf("processing env config: %w", err)
    }
    return &cfg, nil
}
```

### YAML Config File

```yaml
server:
  port: 8080
  read_timeout: 10s
  write_timeout: 10s

database:
  dsn: "postgres://user:pass@localhost:5432/mydb?sslmode=disable"
  max_open_conns: 25
  max_idle_conns: 5
  conn_max_lifetime: 5m
  conn_max_idle_time: 1m

auth:
  jwt_secret: "${JWT_SECRET}"
  token_expiry: 24h

log:
  level: info
  format: json
```

---

## 5. Testing

### HTTP Handler Tests

```go
func TestMerchantHandler_Create(t *testing.T) {
    gin.SetMode(gin.TestMode)

    mockService := &MockMerchantService{}
    handler := NewMerchantHandler(mockService)

    router := gin.New()
    router.POST("/merchants", handler.Create)

    body := `{"mid":"123456","name":"Test Shop","type":"physical"}`
    req := httptest.NewRequest(http.MethodPost, "/merchants", strings.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    w := httptest.NewRecorder()

    mockService.On("Create", mock.Anything, "123456", "Test Shop", "physical").
        Return(&Merchant{ID: 1, MID: "123456", Name: "Test Shop"}, nil)

    router.ServeHTTP(w, req)

    assert.Equal(t, http.StatusCreated, w.Code)

    var resp MerchantResponse
    err := json.Unmarshal(w.Body.Bytes(), &resp)
    assert.NoError(t, err)
    assert.Equal(t, "123456", resp.MID)
    assert.Equal(t, "Test Shop", resp.Name)

    mockService.AssertExpectations(t)
}
```

### Table-Driven Tests

```go
func TestMerchantHandler_GetByID(t *testing.T) {
    gin.SetMode(gin.TestMode)

    tests := []struct {
        name           string
        id             string
        mockReturn     *Merchant
        mockErr        error
        expectedStatus int
    }{
        {
            name:           "found",
            id:             "1",
            mockReturn:     &Merchant{ID: 1, MID: "123", Name: "Shop"},
            expectedStatus: http.StatusOK,
        },
        {
            name:           "not found",
            id:             "999",
            mockErr:        ErrMerchantNotFound,
            expectedStatus: http.StatusNotFound,
        },
        {
            name:           "invalid id",
            id:             "abc",
            expectedStatus: http.StatusBadRequest,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            mockService := &MockMerchantService{}
            handler := NewMerchantHandler(mockService)

            router := gin.New()
            router.Use(ErrorMiddleware())
            router.GET("/merchants/:id", handler.GetByID)

            if tt.id != "abc" {
                id, _ := strconv.ParseInt(tt.id, 10, 64)
                mockService.On("FindByID", mock.Anything, id).
                    Return(tt.mockReturn, tt.mockErr)
            }

            req := httptest.NewRequest(http.MethodGet, "/merchants/"+tt.id, nil)
            w := httptest.NewRecorder()
            router.ServeHTTP(w, req)

            assert.Equal(t, tt.expectedStatus, w.Code)
        })
    }
}
```

### Mock Repository with Interfaces

```go
type MockMerchantService struct {
    mock.Mock
}

func (m *MockMerchantService) Create(ctx context.Context, mid, name, typ string) (*Merchant, error) {
    args := m.Called(ctx, mid, name, typ)
    if args.Get(0) == nil {
        return nil, args.Error(1)
    }
    return args.Get(0).(*Merchant), args.Error(1)
}

func (m *MockMerchantService) FindByID(ctx context.Context, id int64) (*Merchant, error) {
    args := m.Called(ctx, id)
    if args.Get(0) == nil {
        return nil, args.Error(1)
    }
    return args.Get(0).(*Merchant), args.Error(1)
}
```

### Test Suite with testify/suite

```go
type MerchantRepoSuite struct {
    suite.Suite
    db   *sqlx.DB
    repo MerchantRepository
}

func (s *MerchantRepoSuite) SetupSuite() {
    db, err := sqlx.Connect("postgres", os.Getenv("TEST_DATABASE_DSN"))
    s.Require().NoError(err)
    s.db = db
    s.repo = NewMerchantRepository(db)
}

func (s *MerchantRepoSuite) TearDownSuite() {
    s.db.Close()
}

func (s *MerchantRepoSuite) SetupTest() {
    _, err := s.db.Exec("DELETE FROM merchants")
    s.Require().NoError(err)
}

func (s *MerchantRepoSuite) TestCreate() {
    merchant := &Merchant{MID: "12345", Name: "Test", Status: "active"}
    created, err := s.repo.Create(context.Background(), merchant)
    s.NoError(err)
    s.NotZero(created.ID)
    s.Equal("12345", created.MID)
}

func TestMerchantRepoSuite(t *testing.T) {
    suite.Run(t, new(MerchantRepoSuite))
}
```

---

## 6. Error Handling

### Custom Error Types

```go
type AppError struct {
    Code    int    `json:"-"`
    Type    string `json:"type"`
    Title   string `json:"title"`
    Detail  string `json:"detail"`
    Instance string `json:"instance,omitempty"`
}

func (e *AppError) Error() string {
    return e.Detail
}

var (
    ErrMerchantNotFound = &AppError{
        Code:  http.StatusNotFound,
        Type:  "https://api.example.com/errors/not-found",
        Title: "Merchant Not Found",
    }
    ErrMerchantConflict = &AppError{
        Code:  http.StatusConflict,
        Type:  "https://api.example.com/errors/conflict",
        Title: "Merchant Already Exists",
    }
)

func NewNotFoundError(detail string) *AppError {
    return &AppError{
        Code:   http.StatusNotFound,
        Type:   "https://api.example.com/errors/not-found",
        Title:  "Resource Not Found",
        Detail: detail,
    }
}

func NewValidationError(detail string) *AppError {
    return &AppError{
        Code:   http.StatusBadRequest,
        Type:   "https://api.example.com/errors/validation",
        Title:  "Validation Error",
        Detail: detail,
    }
}
```

### Centralized Error Middleware

```go
func ErrorMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        c.Next()

        if len(c.Errors) == 0 {
            return
        }

        err := c.Errors.Last().Err

        var appErr *AppError
        if errors.As(err, &appErr) {
            appErr.Instance = c.Request.URL.Path
            c.JSON(appErr.Code, appErr)
            return
        }

        // Fallback for unexpected errors
        slog.Error("unhandled error",
            "path", c.Request.URL.Path,
            "error", err.Error(),
        )
        c.JSON(http.StatusInternalServerError, &AppError{
            Code:     http.StatusInternalServerError,
            Type:     "https://api.example.com/errors/internal",
            Title:    "Internal Server Error",
            Detail:   "An unexpected error occurred",
            Instance: c.Request.URL.Path,
        })
    }
}
```

### gin.ErrorType Classification

```go
func classifyError(c *gin.Context, err error) {
    var appErr *AppError
    if errors.As(err, &appErr) {
        if appErr.Code >= 500 {
            _ = c.Error(err).SetType(gin.ErrorTypePrivate)
        } else {
            _ = c.Error(err).SetType(gin.ErrorTypePublic)
        }
    } else {
        _ = c.Error(err).SetType(gin.ErrorTypePrivate)
    }
}
```

---

## Anti-Patterns (Gin-Specific)

- **Goroutine leaks in handlers** — never launch goroutines referencing `*gin.Context` without copying needed values; use `c.Copy()` if the goroutine outlives the request
- **Missing `c.Abort()` in middleware** — calling `c.JSON()` without `c.AbortWithStatusJSON()` lets subsequent handlers execute
- **Business logic in handlers** — handlers should only bind input, call services, and format output
- **`panic()` recovery misuse** — relying on `panic/recover` for control flow instead of returning errors
- **Global DB connections without pool config** — always set `MaxOpenConns`, `MaxIdleConns`, `ConnMaxLifetime`
- **Missing input validation** — always use `ShouldBindJSON`/`ShouldBindQuery` with struct tags before processing
- **Using `c.Bind()` instead of `c.ShouldBind()`** — `c.Bind()` auto-aborts with 400; prefer `ShouldBind` for custom error responses
- **Storing request-scoped data in package globals** — use `c.Set()`/`c.Get()` for per-request values
