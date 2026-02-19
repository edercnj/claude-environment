# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Go Testing Conventions

## Framework

- **`testing`** package (standard library)
- **`testify/assert`** for assertions
- **`testify/require`** for fatal assertions
- Test files: `*_test.go` in same package

## Coverage Thresholds

| Metric          | Minimum |
| --------------- | ------- |
| Line Coverage   | >= 95%  |
| Branch Coverage | >= 90%  |

## Naming Convention

```
TestFunctionName_Scenario_Expected
```

```go
func TestFindByMID_ExistingMerchant_ReturnsMerchant(t *testing.T) { ... }
func TestFindByMID_NonexistentMID_ReturnsNotFoundError(t *testing.T) { ... }
func TestCreateMerchant_DuplicateMID_ReturnsDuplicateError(t *testing.T) { ... }
```

## Table-Driven Tests (Mandatory)

```go
func TestCentsDecisionEngine_Decide(t *testing.T) {
    tests := []struct {
        name       string
        amount     string
        wantRC     string
        wantDesc   string
    }{
        {
            name:     "approved cents .00",
            amount:   "100.00",
            wantRC:   "00",
            wantDesc: "approved",
        },
        {
            name:     "insufficient funds cents .51",
            amount:   "100.51",
            wantRC:   "51",
            wantDesc: "insufficient funds",
        },
        {
            name:     "generic error cents .05",
            amount:   "100.05",
            wantRC:   "05",
            wantDesc: "generic error",
        },
        {
            name:     "invalid card cents .14",
            amount:   "100.14",
            wantRC:   "14",
            wantDesc: "invalid card",
        },
    }

    engine := NewCentsDecisionEngine()

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            amount, _ := decimal.NewFromString(tt.amount)
            result := engine.Decide(amount)

            assert.Equal(t, tt.wantRC, result.ResponseCode)
        })
    }
}
```

## Test Helpers

```go
// CORRECT - use t.Helper() for helper functions
func createTestMerchant(t *testing.T, mid string) *Merchant {
    t.Helper()
    return &Merchant{
        MID:      mid,
        Name:     "Test Store",
        Document: "12345678000190",
        MCC:      "5411",
        Status:   StatusActive,
    }
}

func assertMerchantEqual(t *testing.T, expected, actual *Merchant) {
    t.Helper()
    assert.Equal(t, expected.MID, actual.MID)
    assert.Equal(t, expected.Name, actual.Name)
    assert.Equal(t, expected.Status, actual.Status)
}
```

## HTTP Testing

```go
func TestMerchantHandler_Create(t *testing.T) {
    tests := []struct {
        name       string
        body       string
        wantStatus int
    }{
        {
            name:       "valid payload returns 201",
            body:       `{"mid":"MID001","name":"Test","document":"12345678000190","mcc":"5411"}`,
            wantStatus: http.StatusCreated,
        },
        {
            name:       "invalid payload returns 400",
            body:       `{"mid":""}`,
            wantStatus: http.StatusBadRequest,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            req := httptest.NewRequest(http.MethodPost, "/api/v1/merchants",
                strings.NewReader(tt.body))
            req.Header.Set("Content-Type", "application/json")
            rec := httptest.NewRecorder()

            handler.ServeHTTP(rec, req)

            assert.Equal(t, tt.wantStatus, rec.Code)
        })
    }
}
```

## Mocking

```go
// Using testify/mock
type MockMerchantRepository struct {
    mock.Mock
}

func (m *MockMerchantRepository) FindByMID(ctx context.Context, mid string) (*Merchant, error) {
    args := m.Called(ctx, mid)
    if args.Get(0) == nil {
        return nil, args.Error(1)
    }
    return args.Get(0).(*Merchant), args.Error(1)
}

func TestMerchantService_FindByMID(t *testing.T) {
    repo := new(MockMerchantRepository)
    expected := createTestMerchant(t, "MID001")
    repo.On("FindByMID", mock.Anything, "MID001").Return(expected, nil)

    service := NewMerchantService(repo)
    result, err := service.FindByMID(context.Background(), "MID001")

    require.NoError(t, err)
    assert.Equal(t, "MID001", result.MID)
    repo.AssertExpectations(t)
}
```

## Using gomock

```go
//go:generate mockgen -source=repository.go -destination=mock_repository_test.go -package=merchant

func TestMerchantService_Create(t *testing.T) {
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()

    repo := NewMockMerchantRepository(ctrl)
    repo.EXPECT().
        FindByMID(gomock.Any(), "MID001").
        Return(nil, ErrMerchantNotFound)
    repo.EXPECT().
        Save(gomock.Any(), gomock.Any()).
        Return(nil)

    service := NewMerchantService(repo)
    err := service.Create(context.Background(), createTestMerchant(t, "MID001"))
    require.NoError(t, err)
}
```

## Test Cleanup

```go
func TestWithDatabase(t *testing.T) {
    db := setupTestDB(t)
    t.Cleanup(func() {
        db.Close()
    })

    // test code using db
}
```

## Benchmarks

```go
func BenchmarkCentsDecisionEngine_Decide(b *testing.B) {
    engine := NewCentsDecisionEngine()
    amount, _ := decimal.NewFromString("100.00")

    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        engine.Decide(amount)
    }
}
```

## Anti-Patterns

- Tests without `t.Run()` for subtests
- Hardcoded test data without helper functions
- Tests that depend on execution order
- Using `fmt.Println` for debugging in tests
- Tests without error checking (`require.NoError`)
- Sleeping instead of using channels or conditions
