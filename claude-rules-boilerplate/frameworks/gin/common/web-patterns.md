# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Gin — Web Patterns (Handlers, Binding, Validation)

## Route Groups

```go
func SetupRoutes(r *gin.Engine, h *MerchantHandler) {
    v1 := r.Group("/api/v1")
    {
        merchants := v1.Group("/merchants")
        {
            merchants.GET("", h.List)
            merchants.POST("", h.Create)
            merchants.GET("/:id", h.FindByID)
            merchants.PUT("/:id", h.Update)
            merchants.DELETE("/:id", h.Delete)
        }
    }
}
```

## Handler Functions

```go
type MerchantHandler struct {
    service MerchantService
}

func NewMerchantHandler(service MerchantService) *MerchantHandler {
    return &MerchantHandler{service: service}
}

func (h *MerchantHandler) Create(c *gin.Context) {
    var req CreateMerchantRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, newValidationError(err))
        return
    }

    merchant, err := h.service.Create(c.Request.Context(), req)
    if err != nil {
        handleServiceError(c, err)
        return
    }

    c.JSON(http.StatusCreated, toMerchantResponse(merchant))
}

func (h *MerchantHandler) FindByID(c *gin.Context) {
    id, err := strconv.ParseInt(c.Param("id"), 10, 64)
    if err != nil {
        c.JSON(http.StatusBadRequest, ProblemDetail{Type: "/errors/bad-request", Status: 400, Detail: "Invalid ID"})
        return
    }

    merchant, err := h.service.FindByID(c.Request.Context(), id)
    if err != nil {
        handleServiceError(c, err)
        return
    }

    c.JSON(http.StatusOK, toMerchantResponse(merchant))
}

func (h *MerchantHandler) List(c *gin.Context) {
    page, _ := strconv.Atoi(c.DefaultQuery("page", "0"))
    limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))

    merchants, total, err := h.service.List(c.Request.Context(), page, limit)
    if err != nil {
        handleServiceError(c, err)
        return
    }

    c.JSON(http.StatusOK, newPaginatedResponse(merchants, page, limit, total))
}
```

## Request Binding and Validation

```go
type CreateMerchantRequest struct {
    MID      string `json:"mid" binding:"required,max=15"`
    Name     string `json:"name" binding:"required,max=100"`
    Document string `json:"document" binding:"required,len=14,numeric"`
    MCC      string `json:"mcc" binding:"required,len=4,numeric"`
}

type UpdateMerchantRequest struct {
    Name string `json:"name" binding:"omitempty,max=100"`
    MCC  string `json:"mcc" binding:"omitempty,len=4,numeric"`
}
```

## Error Response (RFC 7807)

```go
type ProblemDetail struct {
    Type     string            `json:"type"`
    Title    string            `json:"title"`
    Status   int               `json:"status"`
    Detail   string            `json:"detail"`
    Instance string            `json:"instance,omitempty"`
    Extra    map[string]any    `json:"extensions,omitempty"`
}

func handleServiceError(c *gin.Context, err error) {
    switch {
    case errors.Is(err, ErrNotFound):
        c.JSON(http.StatusNotFound, ProblemDetail{Type: "/errors/not-found", Title: "Not Found", Status: 404, Detail: err.Error()})
    case errors.Is(err, ErrConflict):
        c.JSON(http.StatusConflict, ProblemDetail{Type: "/errors/conflict", Title: "Conflict", Status: 409, Detail: err.Error()})
    default:
        c.JSON(http.StatusInternalServerError, ProblemDetail{Type: "/errors/internal-error", Title: "Internal Error", Status: 500, Detail: "Internal server error"})
    }
}
```

## Anti-Patterns

- Do NOT put business logic in handler functions -- delegate to services
- Do NOT use `c.Bind()` (panics on error) -- use `c.ShouldBindJSON()`
- Do NOT return raw database structs -- map to response DTOs
- Do NOT ignore error returns from service calls
- Do NOT use `c.String()` for API responses -- always use `c.JSON()`
