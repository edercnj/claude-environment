# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# .NET — Configuration Patterns

## appsettings.json Structure

```json
{
  "Server": {
    "Port": 8080
  },
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=simulator;Username=simulator;Password=simulator"
  },
  "Auth": {
    "ApiKey": "dev-key-1234567890123456"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "OpenTelemetry": {
    "Enabled": false,
    "Endpoint": "http://otel-collector:4317"
  }
}
```

## Environment-Specific Files

```
appsettings.json                    # Base shared
appsettings.Development.json        # Dev overrides
appsettings.Test.json               # Test overrides
appsettings.Production.json         # Prod overrides
```

```json
// appsettings.Production.json
{
  "Logging": {
    "LogLevel": { "Default": "Information" }
  },
  "OpenTelemetry": {
    "Enabled": true
  }
}
```

## Options Pattern

```csharp
public class AuthOptions
{
    public const string SectionName = "Auth";
    public string ApiKey { get; set; } = string.Empty;
}

public class OpenTelemetryOptions
{
    public const string SectionName = "OpenTelemetry";
    public bool Enabled { get; set; }
    public string Endpoint { get; set; } = "http://otel-collector:4317";
}

// Registration
builder.Services.Configure<AuthOptions>(builder.Configuration.GetSection(AuthOptions.SectionName));
builder.Services.Configure<OpenTelemetryOptions>(builder.Configuration.GetSection(OpenTelemetryOptions.SectionName));
```

## IOptions Usage

```csharp
public class ApiKeyAuthHandler
{
    private readonly AuthOptions _authOptions;

    public ApiKeyAuthHandler(IOptions<AuthOptions> options)
    {
        _authOptions = options.Value;
    }

    public bool Validate(string? apiKey)
    {
        return !string.IsNullOrEmpty(apiKey) && apiKey == _authOptions.ApiKey;
    }
}
```

## Options Variants

| Interface              | Lifetime   | Reload | Use Case                        |
| ---------------------- | ---------- | ------ | ------------------------------- |
| `IOptions<T>`          | Singleton  | No     | Static config, no hot-reload    |
| `IOptionsSnapshot<T>`  | Scoped     | Yes    | Config that changes per-request |
| `IOptionsMonitor<T>`   | Singleton  | Yes    | Long-lived services with reload |

## Environment Variable Override

Environment variables override JSON config with `__` separator:

| JSON Path                  | Env Variable                       |
| -------------------------- | ---------------------------------- |
| ConnectionStrings:Default  | ConnectionStrings__DefaultConnection |
| Auth:ApiKey                | Auth__ApiKey                       |
| OpenTelemetry:Enabled      | OpenTelemetry__Enabled             |
| Server:Port                | Server__Port                       |

## Validation at Startup

```csharp
builder.Services.AddOptions<AuthOptions>()
    .BindConfiguration(AuthOptions.SectionName)
    .Validate(o => !string.IsNullOrEmpty(o.ApiKey) && o.ApiKey.Length >= 16, "API key must be at least 16 characters")
    .ValidateOnStart();
```

## Anti-Patterns

- Do NOT inject `IConfiguration` directly into services -- use the Options pattern
- Do NOT put secrets in `appsettings.json` committed to Git -- use User Secrets or env vars
- Do NOT skip `ValidateOnStart()` -- invalid config should crash at startup
- Do NOT use `IOptions<T>` when you need hot-reload -- use `IOptionsMonitor<T>`
- Do NOT access `Configuration["key"]` with string keys scattered in code -- centralize in Options classes
