# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Gin — Middleware Patterns
> Extends: `core/06-api-design-principles.md`

## Middleware Chain

```
Request → Recovery → Logger → CORS → RateLimit → Auth → Handler → Response
```

## Recovery Middleware

```go
func RecoveryMiddleware(logger *slog.Logger) gin.HandlerFunc {
    return func(c *gin.Context) {
        defer func() {
            if err := recover(); err != nil {
                logger.Error("panic recovered", "error", err, "path", c.Request.URL.Path)
                c.AbortWithStatusJSON(http.StatusInternalServerError, ProblemDetail{
                    Type:   "/errors/internal-error",
                    Title:  "Internal Server Error",
                    Status: 500,
                    Detail: "An unexpected error occurred",
                })
            }
        }()
        c.Next()
    }
}
```

## Request Logging Middleware

```go
func LoggingMiddleware(logger *slog.Logger) gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        path := c.Request.URL.Path

        c.Next()

        logger.Info("request completed",
            "method", c.Request.Method,
            "path", path,
            "status", c.Writer.Status(),
            "duration_ms", time.Since(start).Milliseconds(),
            "client_ip", c.ClientIP(),
        )
    }
}
```

## CORS Middleware

```go
func CORSMiddleware(allowedOrigins []string) gin.HandlerFunc {
    return func(c *gin.Context) {
        origin := c.GetHeader("Origin")
        for _, allowed := range allowedOrigins {
            if allowed == "*" || allowed == origin {
                c.Header("Access-Control-Allow-Origin", origin)
                c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
                c.Header("Access-Control-Allow-Headers", "Content-Type, X-API-Key")
                break
            }
        }
        if c.Request.Method == "OPTIONS" {
            c.AbortWithStatus(http.StatusNoContent)
            return
        }
        c.Next()
    }
}
```

## Authentication Middleware

```go
func APIKeyAuth(validKey string) gin.HandlerFunc {
    return func(c *gin.Context) {
        key := c.GetHeader("X-API-Key")
        if key == "" || key != validKey {
            c.AbortWithStatusJSON(http.StatusUnauthorized, ProblemDetail{
                Type:   "/errors/unauthorized",
                Title:  "Unauthorized",
                Status: 401,
                Detail: "Invalid or missing API key",
            })
            return
        }
        c.Next()
    }
}
```

## Rate Limiting Middleware

```go
func RateLimitMiddleware(rps int) gin.HandlerFunc {
    limiter := rate.NewLimiter(rate.Limit(rps), rps)
    return func(c *gin.Context) {
        if !limiter.Allow() {
            c.AbortWithStatusJSON(http.StatusTooManyRequests, ProblemDetail{
                Type:   "/errors/too-many-requests",
                Title:  "Too Many Requests",
                Status: 429,
                Detail: "Rate limit exceeded",
            })
            return
        }
        c.Next()
    }
}
```

## Registration

```go
r := gin.New()
r.Use(RecoveryMiddleware(logger))
r.Use(LoggingMiddleware(logger))
r.Use(CORSMiddleware(cfg.CORSOrigins))

api := r.Group("/api/v1")
api.Use(APIKeyAuth(cfg.APIKey))
api.Use(RateLimitMiddleware(100))
```

## Anti-Patterns

- Do NOT use `gin.Default()` in production -- build the middleware chain explicitly
- Do NOT forget `c.Abort()` after writing error responses in middleware
- Do NOT log sensitive data (API keys, tokens) in logging middleware
- Do NOT use global rate limiters without per-client scoping for production
