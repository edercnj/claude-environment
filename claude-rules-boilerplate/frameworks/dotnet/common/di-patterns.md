# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# .NET — Dependency Injection Patterns
> Extends: `core/01-clean-code.md`, `core/02-solid-principles.md`

## Service Registration

```csharp
var builder = WebApplication.CreateBuilder(args);

// Singleton -- one instance for the entire application
builder.Services.AddSingleton<IAppConfig, AppConfig>();

// Scoped -- one instance per HTTP request
builder.Services.AddScoped<IMerchantService, MerchantService>();
builder.Services.AddScoped<IMerchantRepository, MerchantRepository>();

// Transient -- new instance every time
builder.Services.AddTransient<IValidator<CreateMerchantRequest>, CreateMerchantValidator>();
```

## Service Lifetimes

| Lifetime   | Scope                      | Use Case                          |
| ---------- | -------------------------- | --------------------------------- |
| Singleton  | Application lifetime       | Config, caching, logging          |
| Scoped     | Per HTTP request           | DbContext, services, repositories |
| Transient  | Per injection              | Lightweight stateless helpers     |

## Constructor Injection

```csharp
public class MerchantService : IMerchantService
{
    private readonly IMerchantRepository _repository;
    private readonly ILogger<MerchantService> _logger;

    public MerchantService(IMerchantRepository repository, ILogger<MerchantService> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<MerchantResponse> FindByIdAsync(long id)
    {
        var merchant = await _repository.FindByIdAsync(id);
        if (merchant is null)
            throw new MerchantNotFoundException(id);
        return merchant.ToResponse();
    }
}
```

## Extension Methods for Registration

```csharp
public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddApplicationServices(this IServiceCollection services)
    {
        services.AddScoped<IMerchantService, MerchantService>();
        services.AddScoped<ITerminalService, TerminalService>();
        return services;
    }

    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration config)
    {
        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(config.GetConnectionString("DefaultConnection")));
        services.AddScoped<IMerchantRepository, MerchantRepository>();
        return services;
    }
}

// Usage in Program.cs
builder.Services.AddApplicationServices();
builder.Services.AddInfrastructure(builder.Configuration);
```

## Keyed Services (.NET 8+)

```csharp
builder.Services.AddKeyedScoped<INotificationService, EmailNotificationService>("email");
builder.Services.AddKeyedScoped<INotificationService, SmsNotificationService>("sms");

public class OrderService
{
    public OrderService([FromKeyedServices("email")] INotificationService notifier) { }
}
```

## Anti-Patterns

- Do NOT use `new` to create services that have dependencies -- register in DI container
- Do NOT inject `IServiceProvider` directly (service locator) -- use constructor injection
- Do NOT register `DbContext` as Singleton -- it is NOT thread-safe, use Scoped
- Do NOT capture Scoped services in Singleton services -- causes captive dependency
- Do NOT use property injection -- always use constructor injection
