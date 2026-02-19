# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Gin — Testing Patterns
> Extends: `core/03-testing-philosophy.md`

## httptest with Gin

```go
func setupTestRouter(service MerchantService) *gin.Engine {
    gin.SetMode(gin.TestMode)
    r := gin.New()
    h := NewMerchantHandler(service)
    SetupRoutes(r, h)
    return r
}

func TestCreateMerchant_ValidPayload_Returns201(t *testing.T) {
    mockService := &MockMerchantService{
        CreateFn: func(ctx context.Context, req CreateMerchantRequest) (*Merchant, error) {
            return &Merchant{ID: 1, MID: req.MID, Name: req.Name}, nil
        },
    }
    router := setupTestRouter(mockService)

    body := `{"mid":"123456789012345","name":"Test","document":"12345678000190","mcc":"5411"}`
    req := httptest.NewRequest(http.MethodPost, "/api/v1/merchants", strings.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("X-API-Key", "test-key")
    w := httptest.NewRecorder()

    router.ServeHTTP(w, req)

    assert.Equal(t, http.StatusCreated, w.Code)
    var resp MerchantResponse
    err := json.Unmarshal(w.Body.Bytes(), &resp)
    assert.NoError(t, err)
    assert.Equal(t, "123456789012345", resp.MID)
}
```

## Table-Driven Tests

```go
func TestCreateMerchant_Validation(t *testing.T) {
    tests := []struct {
        name       string
        body       string
        wantStatus int
    }{
        {"empty mid", `{"mid":"","name":"Test","document":"12345678000190","mcc":"5411"}`, 400},
        {"missing name", `{"mid":"123","document":"12345678000190","mcc":"5411"}`, 400},
        {"invalid mcc", `{"mid":"123","name":"Test","document":"12345678000190","mcc":"54"}`, 400},
        {"valid request", `{"mid":"123456789012345","name":"Test","document":"12345678000190","mcc":"5411"}`, 201},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            mockService := &MockMerchantService{
                CreateFn: func(ctx context.Context, req CreateMerchantRequest) (*Merchant, error) {
                    return &Merchant{ID: 1, MID: req.MID}, nil
                },
            }
            router := setupTestRouter(mockService)

            req := httptest.NewRequest(http.MethodPost, "/api/v1/merchants", strings.NewReader(tt.body))
            req.Header.Set("Content-Type", "application/json")
            w := httptest.NewRecorder()

            router.ServeHTTP(w, req)

            assert.Equal(t, tt.wantStatus, w.Code)
        })
    }
}
```

## Mock Service Interface

```go
type MockMerchantService struct {
    CreateFn   func(ctx context.Context, req CreateMerchantRequest) (*Merchant, error)
    FindByIDFn func(ctx context.Context, id int64) (*Merchant, error)
    ListFn     func(ctx context.Context, page, limit int) ([]*Merchant, int64, error)
}

func (m *MockMerchantService) Create(ctx context.Context, req CreateMerchantRequest) (*Merchant, error) {
    return m.CreateFn(ctx, req)
}

func (m *MockMerchantService) FindByID(ctx context.Context, id int64) (*Merchant, error) {
    return m.FindByIDFn(ctx, id)
}
```

## Test Context Helper

```go
func createTestContext() (*gin.Context, *httptest.ResponseRecorder) {
    gin.SetMode(gin.TestMode)
    w := httptest.NewRecorder()
    c, _ := gin.CreateTestContext(w)
    return c, w
}
```

## Naming Convention

```
Test[Function]_[Scenario]_[Expected]
```

Examples: `TestCreateMerchant_ValidPayload_Returns201`, `TestFindByID_NotFound_Returns404`

## Anti-Patterns

- Do NOT use `gin.Default()` in tests -- use `gin.New()` with `gin.TestMode`
- Do NOT test with real databases in unit tests -- mock the service layer
- Do NOT skip table-driven tests for validation scenarios
- Do NOT use `t.Fatal()` for expected errors -- use `assert.Error()`
