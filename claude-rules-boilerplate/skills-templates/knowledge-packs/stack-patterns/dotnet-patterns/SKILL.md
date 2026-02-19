---
name: dotnet-patterns
description: ".NET 8+-specific patterns: built-in DI, Entity Framework Core, Minimal APIs, IOptions, WebApplicationFactory testing, NativeAOT, ProblemDetails error handling. Internal reference for agents producing .NET code."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: .NET 8+ Patterns

## Purpose

Provides .NET 8+-specific implementation patterns that supplement the generic layer templates. Agents reference this pack when generating code for a C# + .NET 8+ project.

---

## 1. Dependency Injection

### Built-In DI with IServiceCollection

```csharp
var builder = WebApplication.CreateBuilder(args);

// Scoped: one instance per HTTP request
builder.Services.AddScoped<IMerchantRepository, MerchantRepository>();
builder.Services.AddScoped<IMerchantService, MerchantService>();

// Singleton: one instance for application lifetime
builder.Services.AddSingleton<ITokenProvider, JwtTokenProvider>();

// Transient: new instance every time it is requested
builder.Services.AddTransient<IRequestValidator, RequestValidator>();

// Options pattern
builder.Services.Configure<DatabaseOptions>(
    builder.Configuration.GetSection("Database"));
builder.Services.Configure<AuthOptions>(
    builder.Configuration.GetSection("Auth"));

var app = builder.Build();
```

### Constructor Injection

```csharp
public class MerchantService : IMerchantService
{
    private readonly IMerchantRepository _repository;
    private readonly ILogger<MerchantService> _logger;
    private readonly IOptionsSnapshot<FeatureOptions> _featureOptions;

    public MerchantService(
        IMerchantRepository repository,
        ILogger<MerchantService> logger,
        IOptionsSnapshot<FeatureOptions> featureOptions)
    {
        _repository = repository;
        _logger = logger;
        _featureOptions = featureOptions;
    }

    public async Task<Merchant> CreateAsync(CreateMerchantCommand command, CancellationToken ct)
    {
        if (_featureOptions.Value.RequireApproval)
        {
            _logger.LogInformation("Merchant creation requires approval for MID {Mid}", command.Mid);
        }

        var merchant = Merchant.Create(command.Mid, command.Name, command.Type);
        await _repository.AddAsync(merchant, ct);
        return merchant;
    }
}
```

### IOptions Variants

| Interface | Lifetime | Reloads on Change | Use When |
|-----------|----------|-------------------|----------|
| `IOptions<T>` | Singleton | No | Static config, never changes |
| `IOptionsSnapshot<T>` | Scoped | Yes (per request) | Config that may change between requests |
| `IOptionsMonitor<T>` | Singleton | Yes (callback) | Singleton services needing live updates |

```csharp
public class FeatureOptions
{
    public const string SectionName = "Features";

    public bool RequireApproval { get; set; }
    public int MaxMerchantsPerAccount { get; set; } = 100;
    public TimeSpan CacheDuration { get; set; } = TimeSpan.FromMinutes(5);
}

// Registration
builder.Services.Configure<FeatureOptions>(
    builder.Configuration.GetSection(FeatureOptions.SectionName));

// Validation at startup
builder.Services.AddOptionsWithValidateOnStart<FeatureOptions>()
    .Bind(builder.Configuration.GetSection(FeatureOptions.SectionName))
    .ValidateDataAnnotations();
```

### FORBIDDEN

- **Service Locator pattern** — never inject `IServiceProvider` and call `GetService<T>()` manually; use constructor injection
- **`new` for DI-managed services** — never instantiate services with `new MerchantService(...)` when they should be resolved from the container

---

## 2. Entity Framework Core

### DbContext

```csharp
public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<MerchantEntity> Merchants => Set<MerchantEntity>();
    public DbSet<AuditLogEntity> AuditLogs => Set<AuditLogEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        var entries = ChangeTracker.Entries<BaseEntity>();
        foreach (var entry in entries)
        {
            switch (entry.State)
            {
                case EntityState.Added:
                    entry.Entity.CreatedAt = DateTimeOffset.UtcNow;
                    entry.Entity.UpdatedAt = DateTimeOffset.UtcNow;
                    break;
                case EntityState.Modified:
                    entry.Entity.UpdatedAt = DateTimeOffset.UtcNow;
                    break;
            }
        }
        return base.SaveChangesAsync(cancellationToken);
    }
}
```

### Entity Configuration

```csharp
public class MerchantEntity : BaseEntity
{
    public long Id { get; set; }
    public string Mid { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Status { get; set; } = "active";
    public MerchantType Type { get; set; }

    // Navigation property
    public ICollection<TransactionEntity> Transactions { get; set; } = [];
}

public class MerchantEntityConfiguration : IEntityTypeConfiguration<MerchantEntity>
{
    public void Configure(EntityTypeBuilder<MerchantEntity> builder)
    {
        builder.ToTable("merchants");
        builder.HasKey(m => m.Id);
        builder.Property(m => m.Mid).HasMaxLength(15).IsRequired();
        builder.Property(m => m.Name).HasMaxLength(100).IsRequired();
        builder.Property(m => m.Status).HasMaxLength(20).IsRequired();
        builder.Property(m => m.Type).HasConversion<string>().HasMaxLength(20);

        builder.HasIndex(m => m.Mid).IsUnique();

        builder.HasMany(m => m.Transactions)
            .WithOne(t => t.Merchant)
            .HasForeignKey(t => t.MerchantId);
    }
}
```

### Repository Pattern with EF Core

```csharp
public class MerchantRepository : IMerchantRepository
{
    private readonly AppDbContext _context;

    public MerchantRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<Merchant?> FindByIdAsync(long id, CancellationToken ct)
    {
        var entity = await _context.Merchants
            .AsNoTracking()
            .FirstOrDefaultAsync(m => m.Id == id, ct);

        return entity?.ToDomain();
    }

    public async Task<(IReadOnlyList<Merchant> Items, int Total)> FindAllAsync(
        int page, int limit, string? status, CancellationToken ct)
    {
        var query = _context.Merchants.AsNoTracking();

        if (!string.IsNullOrEmpty(status))
            query = query.Where(m => m.Status == status);

        var total = await query.CountAsync(ct);

        var items = await query
            .OrderByDescending(m => m.CreatedAt)
            .Skip(page * limit)
            .Take(limit)
            .Select(m => m.ToDomain())
            .ToListAsync(ct);

        return (items, total);
    }

    public async Task AddAsync(Merchant merchant, CancellationToken ct)
    {
        var entity = MerchantEntity.FromDomain(merchant);
        _context.Merchants.Add(entity);
        await _context.SaveChangesAsync(ct);
    }
}
```

### Migrations

```bash
# Add a migration
dotnet ef migrations add CreateMerchants

# Update database
dotnet ef database update

# Generate SQL script (for production)
dotnet ef migrations script --idempotent -o migrations.sql

# Remove last migration (if not applied)
dotnet ef migrations remove
```

### LINQ Queries

```csharp
// Projection query (returns only needed columns)
var summaries = await _context.Merchants
    .AsNoTracking()
    .Where(m => m.Status == "active")
    .Select(m => new MerchantSummary(m.Id, m.Mid, m.Name))
    .ToListAsync(ct);

// Aggregation
var countByStatus = await _context.Merchants
    .GroupBy(m => m.Status)
    .Select(g => new { Status = g.Key, Count = g.Count() })
    .ToListAsync(ct);

// Exists check (efficient — stops at first match)
var exists = await _context.Merchants
    .AnyAsync(m => m.Mid == mid, ct);
```

---

## 3. Web APIs

### Minimal APIs

```csharp
var app = builder.Build();

app.MapGet("/api/v1/merchants", async (
    IMerchantService service,
    [FromQuery] int page = 0,
    [FromQuery] int limit = 20,
    [FromQuery] string? status = null,
    CancellationToken ct = default) =>
{
    var result = await service.FindAllAsync(page, limit, status, ct);
    return Results.Ok(new PaginatedResponse<MerchantResponse>(
        result.Items.Select(m => m.ToResponse()),
        result.Total, page, limit));
});

app.MapGet("/api/v1/merchants/{id:long}", async (
    long id,
    IMerchantService service,
    CancellationToken ct) =>
{
    var merchant = await service.FindByIdAsync(id, ct);
    return merchant is not null
        ? Results.Ok(merchant.ToResponse())
        : Results.Problem(
            title: "Merchant Not Found",
            statusCode: StatusCodes.Status404NotFound,
            type: "https://api.example.com/errors/not-found");
});

app.MapPost("/api/v1/merchants", async (
    CreateMerchantRequest request,
    IMerchantService service,
    IValidator<CreateMerchantRequest> validator,
    CancellationToken ct) =>
{
    var validation = await validator.ValidateAsync(request, ct);
    if (!validation.IsValid)
        return Results.ValidationProblem(validation.ToDictionary());

    var merchant = await service.CreateAsync(request.ToCommand(), ct);
    return Results.Created($"/api/v1/merchants/{merchant.Id}", merchant.ToResponse());
})
.WithName("CreateMerchant")
.Produces<MerchantResponse>(StatusCodes.Status201Created)
.ProducesValidationProblem();

app.MapDelete("/api/v1/merchants/{id:long}", async (
    long id,
    IMerchantService service,
    CancellationToken ct) =>
{
    await service.DeactivateAsync(id, ct);
    return Results.NoContent();
});
```

### Controller-Based (Alternative)

```csharp
[ApiController]
[Route("api/v1/[controller]")]
public class MerchantsController : ControllerBase
{
    private readonly IMerchantService _service;
    private readonly IValidator<CreateMerchantRequest> _validator;

    public MerchantsController(
        IMerchantService service,
        IValidator<CreateMerchantRequest> validator)
    {
        _service = service;
        _validator = validator;
    }

    [HttpGet]
    [ProducesResponseType(typeof(PaginatedResponse<MerchantResponse>), StatusCodes.Status200OK)]
    public async Task<IActionResult> List(
        [FromQuery] int page = 0,
        [FromQuery] int limit = 20,
        [FromQuery] string? status = null,
        CancellationToken ct = default)
    {
        var result = await _service.FindAllAsync(page, limit, status, ct);
        return Ok(new PaginatedResponse<MerchantResponse>(
            result.Items.Select(m => m.ToResponse()),
            result.Total, page, limit));
    }

    [HttpPost]
    [ProducesResponseType(typeof(MerchantResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Create(
        [FromBody] CreateMerchantRequest request,
        CancellationToken ct)
    {
        var validation = await _validator.ValidateAsync(request, ct);
        if (!validation.IsValid)
            return ValidationProblem(new ValidationProblemDetails(validation.ToDictionary()));

        var merchant = await _service.CreateAsync(request.ToCommand(), ct);
        return CreatedAtAction(nameof(GetById), new { id = merchant.Id }, merchant.ToResponse());
    }

    [HttpGet("{id:long}")]
    [ProducesResponseType(typeof(MerchantResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetById(long id, CancellationToken ct)
    {
        var merchant = await _service.FindByIdAsync(id, ct);
        return merchant is not null
            ? Ok(merchant.ToResponse())
            : NotFound();
    }
}
```

### FluentValidation

```csharp
public class CreateMerchantRequestValidator : AbstractValidator<CreateMerchantRequest>
{
    public CreateMerchantRequestValidator()
    {
        RuleFor(x => x.Mid)
            .NotEmpty()
            .MaximumLength(15)
            .Matches(@"^\d+$").WithMessage("MID must contain only digits");

        RuleFor(x => x.Name)
            .NotEmpty()
            .MaximumLength(100);

        RuleFor(x => x.Type)
            .IsInEnum()
            .WithMessage("Type must be Physical or Online");
    }
}

// Registration
builder.Services.AddValidatorsFromAssemblyContaining<CreateMerchantRequestValidator>();
```

### ProblemDetails for RFC 7807

```csharp
builder.Services.AddProblemDetails(options =>
{
    options.CustomizeProblemDetails = context =>
    {
        context.ProblemDetails.Extensions["traceId"] =
            context.HttpContext.TraceIdentifier;
    };
});

// Global exception handler middleware
app.UseExceptionHandler(errorApp =>
{
    errorApp.Run(async context =>
    {
        var exception = context.Features.Get<IExceptionHandlerFeature>()?.Error;
        var logger = context.RequestServices.GetRequiredService<ILogger<Program>>();
        logger.LogError(exception, "Unhandled exception");

        var problemDetails = exception switch
        {
            MerchantNotFoundException ex => new ProblemDetails
            {
                Type = "https://api.example.com/errors/not-found",
                Title = "Merchant Not Found",
                Status = StatusCodes.Status404NotFound,
                Detail = ex.Message,
                Instance = context.Request.Path
            },
            DuplicateMerchantException ex => new ProblemDetails
            {
                Type = "https://api.example.com/errors/conflict",
                Title = "Duplicate Merchant",
                Status = StatusCodes.Status409Conflict,
                Detail = ex.Message,
                Instance = context.Request.Path
            },
            _ => new ProblemDetails
            {
                Type = "https://api.example.com/errors/internal",
                Title = "Internal Server Error",
                Status = StatusCodes.Status500InternalServerError,
                Detail = "An unexpected error occurred",
                Instance = context.Request.Path
            }
        };

        context.Response.StatusCode = problemDetails.Status ?? 500;
        await context.Response.WriteAsJsonAsync(problemDetails);
    });
});
```

---

## 4. Configuration

### appsettings.json Structure

```json
{
  "Server": {
    "Urls": "http://0.0.0.0:8080"
  },
  "Database": {
    "ConnectionString": "Host=localhost;Database=mydb;Username=postgres;Password=secret",
    "MaxPoolSize": 25,
    "CommandTimeout": 30
  },
  "Auth": {
    "JwtSecret": "change-me-in-production",
    "Issuer": "example.com",
    "TokenExpirySecs": 86400
  },
  "Features": {
    "RequireApproval": false,
    "MaxMerchantsPerAccount": 100
  }
}
```

### Environment-Specific Overrides

```json
// appsettings.Development.json
{
  "Database": {
    "ConnectionString": "Host=localhost;Database=mydb_dev;Username=postgres;Password=dev"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Debug"
    }
  }
}

// appsettings.Production.json
{
  "Database": {
    "MaxPoolSize": 50
  },
  "Logging": {
    "LogLevel": {
      "Default": "Warning"
    }
  }
}
```

### IConfiguration Direct Access

```csharp
// For simple one-off values (prefer IOptions<T> for groups)
var connectionString = builder.Configuration.GetConnectionString("Default");
var jwtSecret = builder.Configuration["Auth:JwtSecret"];
```

### User Secrets (Development)

```bash
# Initialize user secrets
dotnet user-secrets init

# Set secrets
dotnet user-secrets set "Database:ConnectionString" "Host=localhost;Database=mydb;Username=admin;Password=real-secret"
dotnet user-secrets set "Auth:JwtSecret" "my-dev-secret-key"
```

### Environment Variable Override

```bash
# Double underscore replaces colon for nested config
export Database__ConnectionString="Host=prod-db;Database=mydb;Username=app;Password=prod-secret"
export Auth__JwtSecret="production-jwt-secret"
```

---

## 5. Testing

### WebApplicationFactory Integration Tests

```csharp
public class MerchantApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;
    private readonly WebApplicationFactory<Program> _factory;

    public MerchantApiTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                // Replace real DB with in-memory
                services.RemoveAll<DbContextOptions<AppDbContext>>();
                services.AddDbContext<AppDbContext>(options =>
                    options.UseInMemoryDatabase("TestDb"));

                // Replace external services with mocks
                services.RemoveAll<ITokenProvider>();
                services.AddSingleton<ITokenProvider>(new MockTokenProvider());
            });
        });
        _client = _factory.CreateClient();
    }

    [Fact]
    public async Task CreateMerchant_ReturnsCreated()
    {
        var request = new CreateMerchantRequest("12345", "Test Shop", MerchantType.Physical);

        var response = await _client.PostAsJsonAsync("/api/v1/merchants", request);

        response.StatusCode.Should().Be(HttpStatusCode.Created);

        var merchant = await response.Content.ReadFromJsonAsync<MerchantResponse>();
        merchant.Should().NotBeNull();
        merchant!.Mid.Should().Be("12345");
        merchant.Name.Should().Be("Test Shop");
    }

    [Fact]
    public async Task GetMerchant_WhenNotFound_Returns404ProblemDetails()
    {
        var response = await _client.GetAsync("/api/v1/merchants/999");

        response.StatusCode.Should().Be(HttpStatusCode.NotFound);

        var problem = await response.Content.ReadFromJsonAsync<ProblemDetails>();
        problem.Should().NotBeNull();
        problem!.Title.Should().Be("Merchant Not Found");
        problem.Type.Should().Be("https://api.example.com/errors/not-found");
    }

    [Fact]
    public async Task CreateMerchant_InvalidRequest_Returns400()
    {
        var request = new CreateMerchantRequest("", "", MerchantType.Physical);

        var response = await _client.PostAsJsonAsync("/api/v1/merchants", request);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task ListMerchants_ReturnsPaginatedResponse()
    {
        // Seed data
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        context.Merchants.AddRange(
            new MerchantEntity { Mid = "001", Name = "Shop A", Status = "active", Type = MerchantType.Physical },
            new MerchantEntity { Mid = "002", Name = "Shop B", Status = "active", Type = MerchantType.Online }
        );
        await context.SaveChangesAsync();

        var response = await _client.GetAsync("/api/v1/merchants?page=0&limit=10");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }
}
```

### Unit Tests with Moq

```csharp
public class MerchantServiceTests
{
    private readonly Mock<IMerchantRepository> _repositoryMock;
    private readonly Mock<ILogger<MerchantService>> _loggerMock;
    private readonly IOptions<FeatureOptions> _options;
    private readonly MerchantService _sut;

    public MerchantServiceTests()
    {
        _repositoryMock = new Mock<IMerchantRepository>();
        _loggerMock = new Mock<ILogger<MerchantService>>();
        _options = Options.Create(new FeatureOptions { RequireApproval = false });
        _sut = new MerchantService(
            _repositoryMock.Object,
            _loggerMock.Object,
            new OptionsWrapper<FeatureOptions>(_options.Value));
    }

    [Fact]
    public async Task CreateAsync_ValidCommand_ReturnsMerchant()
    {
        var command = new CreateMerchantCommand("12345", "Test Shop", MerchantType.Physical);
        _repositoryMock
            .Setup(r => r.AddAsync(It.IsAny<Merchant>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        var result = await _sut.CreateAsync(command, CancellationToken.None);

        result.Should().NotBeNull();
        result.Mid.Should().Be("12345");
        _repositoryMock.Verify(r => r.AddAsync(It.IsAny<Merchant>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task FindByIdAsync_WhenNotFound_ReturnsNull()
    {
        _repositoryMock
            .Setup(r => r.FindByIdAsync(999, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Merchant?)null);

        var result = await _sut.FindByIdAsync(999, CancellationToken.None);

        result.Should().BeNull();
    }
}
```

### FluentAssertions Examples

```csharp
// Object assertions
merchant.Should().NotBeNull();
merchant.Should().BeEquivalentTo(expected, options =>
    options.Excluding(m => m.CreatedAt));

// Collection assertions
merchants.Should().HaveCount(5);
merchants.Should().ContainSingle(m => m.Mid == "12345");
merchants.Should().BeInDescendingOrder(m => m.CreatedAt);

// Exception assertions
var act = () => service.CreateAsync(invalidCommand, CancellationToken.None);
await act.Should().ThrowAsync<ValidationException>()
    .WithMessage("*MID*required*");
```

---

## 6. NativeAOT

### PublishAot Configuration

```xml
<!-- In .csproj -->
<PropertyGroup>
    <PublishAot>true</PublishAot>
    <InvariantGlobalization>true</InvariantGlobalization>
</PropertyGroup>
```

### JSON Source Generators

```csharp
[JsonSerializable(typeof(MerchantResponse))]
[JsonSerializable(typeof(CreateMerchantRequest))]
[JsonSerializable(typeof(PaginatedResponse<MerchantResponse>))]
[JsonSerializable(typeof(ProblemDetails))]
[JsonSerializable(typeof(ValidationProblemDetails))]
[JsonSourceGenerationOptions(
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull)]
public partial class AppJsonSerializerContext : JsonSerializerContext
{
}

// Registration
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.TypeInfoResolverChain.Insert(0, AppJsonSerializerContext.Default);
});
```

### Trimming Annotations

```csharp
// Mark types that must survive trimming
[DynamicallyAccessedMembers(DynamicallyAccessedMemberTypes.All)]
public class MerchantEntity { /* ... */ }

// Suppress trimming warnings when reflection is intentional
[UnconditionalSuppressMessage("Trimming", "IL2026",
    Justification = "Type is preserved via JsonSerializable")]
public static MerchantResponse ToResponse(this Merchant merchant) { /* ... */ }
```

### Reflection-Free Patterns

```csharp
// INSTEAD OF: Activator.CreateInstance<T>()
// USE: factory delegates or explicit construction
builder.Services.AddScoped<IMerchantService>(sp =>
    new MerchantService(
        sp.GetRequiredService<IMerchantRepository>(),
        sp.GetRequiredService<ILogger<MerchantService>>(),
        sp.GetRequiredService<IOptionsSnapshot<FeatureOptions>>()));

// INSTEAD OF: Assembly scanning for validators
// USE: explicit registration
builder.Services.AddScoped<IValidator<CreateMerchantRequest>, CreateMerchantRequestValidator>();
```

### Build Commands

```bash
# Standard build
dotnet build

# Run in development
dotnet run --environment Development

# Publish NativeAOT
dotnet publish -c Release -r linux-x64

# Publish self-contained (non-AOT)
dotnet publish -c Release -r linux-x64 --self-contained
```

---

## Anti-Patterns (.NET-Specific)

- **`async void`** — always use `async Task`; `async void` swallows exceptions and cannot be awaited, causing silent failures and crashes
- **`Task.Result` / `.Wait()` deadlocks** — never block on async code synchronously; this causes thread pool starvation and deadlocks in ASP.NET Core; always use `await`
- **EF Core lazy loading in APIs (N+1)** — avoid `virtual` navigation properties with lazy loading proxies; use `Include()` for eager loading or projection with `Select()`
- **Missing `IDisposable` / `IAsyncDisposable`** — types holding unmanaged resources or `DbContext` references must implement dispose; use `await using` for async disposal
- **Service Locator via `IServiceProvider`** — never inject `IServiceProvider` to resolve services manually; use constructor injection exclusively
- **`static` for stateful services** — static classes cannot participate in DI and make testing difficult; use scoped/singleton DI registrations instead
- **Missing `CancellationToken` propagation** — always accept and forward `CancellationToken` through async call chains to support request cancellation
- **`string` interpolation in log messages** — use structured logging with message templates: `_logger.LogInformation("Created merchant {Mid}", mid)` not `_logger.LogInformation($"Created merchant {mid}")`
- **Capturing `DbContext` in singletons** — `DbContext` is scoped; injecting it into a singleton causes it to outlive its intended scope and leads to concurrency issues
