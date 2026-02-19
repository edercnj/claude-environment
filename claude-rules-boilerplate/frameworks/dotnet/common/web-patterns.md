# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# .NET — Web Patterns (Controllers, Minimal APIs, Validation)

## Controller-Based API

```csharp
[ApiController]
[Route("api/v1/[controller]")]
[Produces("application/json")]
public class MerchantsController : ControllerBase
{
    private readonly IMerchantService _service;

    public MerchantsController(IMerchantService service)
    {
        _service = service;
    }

    [HttpGet]
    [ProducesResponseType(typeof(PaginatedResponse<MerchantResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PaginatedResponse<MerchantResponse>>> List(
        [FromQuery] int page = 0, [FromQuery] int limit = 20)
    {
        return Ok(await _service.ListAsync(page, limit));
    }

    [HttpPost]
    [ProducesResponseType(typeof(MerchantResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<ActionResult<MerchantResponse>> Create([FromBody] CreateMerchantRequest request)
    {
        var merchant = await _service.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = merchant.Id }, merchant);
    }

    [HttpGet("{id:long}")]
    [ProducesResponseType(typeof(MerchantResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<MerchantResponse>> GetById(long id)
    {
        return Ok(await _service.FindByIdAsync(id));
    }

    [HttpDelete("{id:long}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete(long id)
    {
        await _service.DeactivateAsync(id);
        return NoContent();
    }
}
```

## Minimal API (Alternative)

```csharp
app.MapGroup("/api/v1/merchants")
    .MapGet("/", async (IMerchantService service, int page = 0, int limit = 20) =>
        Results.Ok(await service.ListAsync(page, limit)))
    .MapPost("/", async (IMerchantService service, CreateMerchantRequest request) =>
    {
        var merchant = await service.CreateAsync(request);
        return Results.Created($"/api/v1/merchants/{merchant.Id}", merchant);
    })
    .MapGet("/{id:long}", async (IMerchantService service, long id) =>
        Results.Ok(await service.FindByIdAsync(id)));
```

## FluentValidation

```csharp
public class CreateMerchantRequestValidator : AbstractValidator<CreateMerchantRequest>
{
    public CreateMerchantRequestValidator()
    {
        RuleFor(x => x.Mid).NotEmpty().MaximumLength(15);
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Document).NotEmpty().Matches(@"^\d{11,14}$");
        RuleFor(x => x.Mcc).NotEmpty().Length(4).Matches(@"^\d{4}$");
    }
}

// Registration
builder.Services.AddValidatorsFromAssemblyContaining<CreateMerchantRequestValidator>();
builder.Services.AddFluentValidationAutoValidation();
```

## ProblemDetails (RFC 7807)

```csharp
builder.Services.AddProblemDetails(options =>
{
    options.CustomizeProblemDetails = context =>
    {
        context.ProblemDetails.Instance = context.HttpContext.Request.Path;
    };
});

// Global exception handler
app.UseExceptionHandler(appBuilder =>
{
    appBuilder.Run(async context =>
    {
        var exception = context.Features.Get<IExceptionHandlerFeature>()?.Error;
        var problem = exception switch
        {
            MerchantNotFoundException e => new ProblemDetails
            {
                Type = "/errors/not-found", Title = "Not Found", Status = 404,
                Detail = $"Merchant not found: {e.Identifier}",
            },
            MerchantAlreadyExistsException e => new ProblemDetails
            {
                Type = "/errors/conflict", Title = "Conflict", Status = 409,
                Detail = $"Merchant with MID '{e.Mid}' already exists",
            },
            _ => new ProblemDetails
            {
                Type = "/errors/internal-error", Title = "Internal Server Error", Status = 500,
                Detail = "An unexpected error occurred",
            },
        };
        context.Response.StatusCode = problem.Status ?? 500;
        await context.Response.WriteAsJsonAsync(problem);
    });
});
```

## Request/Response Records

```csharp
public record CreateMerchantRequest(string Mid, string Name, string Document, string Mcc);
public record MerchantResponse(long Id, string Mid, string Name, string DocumentMasked, string Mcc, string Status, DateTimeOffset CreatedAt);
public record PaginatedResponse<T>(List<T> Data, PaginationInfo Pagination);
public record PaginationInfo(int Page, int Limit, long Total, int TotalPages);
```

## Anti-Patterns

- Do NOT put business logic in controllers -- delegate to services
- Do NOT return EF entities directly -- map to response DTOs
- Do NOT use `[FromBody]` without validation -- use FluentValidation or Data Annotations
- Do NOT throw plain `Exception` -- use domain-specific exceptions
- Do NOT skip `ProducesResponseType` attributes -- they generate OpenAPI docs
