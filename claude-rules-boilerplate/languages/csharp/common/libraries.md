# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# C# Libraries

## Mandatory

| Library           | Purpose        | Justification                                  |
| ----------------- | -------------- | ---------------------------------------------- |
| xUnit             | Testing        | Modern, extensible, parallel test execution    |
| FluentAssertions  | Assertions     | Readable, rich assertion API                   |
| Serilog           | Logging        | Structured logging, sinks ecosystem            |

### xUnit

```csharp
public class MerchantServiceTests
{
    [Fact]
    public async Task CreateMerchant_ValidPayload_ReturnsMerchant()
    {
        // test implementation
    }

    [Theory]
    [InlineData("100.00", "00")]
    [InlineData("100.51", "51")]
    public void CentsRule_ReturnsExpectedCode(string amount, string expected)
    {
        // parametrized test
    }
}
```

### FluentAssertions

```csharp
using FluentAssertions;

result.Should().NotBeNull();
result.Mid.Should().Be("MID001");
merchants.Should().HaveCount(5);
merchants.Should().AllSatisfy(m => m.Status.Should().Be("ACTIVE"));
action.Should().Throw<MerchantNotFoundException>().WithMessage("*MID001*");
```

### Serilog

```csharp
using Serilog;

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .WriteTo.Console(new JsonFormatter())
    .WriteTo.Seq("http://localhost:5341")
    .Enrich.FromLogContext()
    .CreateLogger();

Log.Information("Merchant {Mid} created with status {Status}",
    merchant.Mid, merchant.Status);

Log.Error(exception, "Processing failed for MTI {Mti} STAN {Stan}",
    mti, stan);
```

## Recommended

| Library           | Purpose            | When to Use                             |
| ----------------- | ------------------ | --------------------------------------- |
| MediatR           | Mediator pattern   | CQRS, decoupled handlers               |
| FluentValidation  | Validation         | Complex validation rules                |
| Polly             | Resilience         | Retry, circuit breaker, timeout         |
| EF Core           | ORM                | Database access                         |
| NSubstitute       | Mocking            | Test doubles                            |
| AutoMapper        | Object mapping     | DTO-to-domain mapping                   |
| Swashbuckle       | OpenAPI            | API documentation                       |
| MassTransit       | Messaging          | Message bus abstraction                 |

### MediatR (CQRS)

```csharp
// Command
public record CreateMerchantCommand(string Mid, string Name, string Document, string Mcc)
    : IRequest<MerchantResponse>;

// Handler
public class CreateMerchantHandler : IRequestHandler<CreateMerchantCommand, MerchantResponse>
{
    private readonly IMerchantRepository _repository;

    public CreateMerchantHandler(IMerchantRepository repository)
    {
        _repository = repository;
    }

    public async Task<MerchantResponse> Handle(
        CreateMerchantCommand request, CancellationToken ct)
    {
        var existing = await _repository.FindByMidAsync(request.Mid, ct);
        if (existing is not null)
            throw new MerchantAlreadyExistsException(request.Mid);

        var merchant = MerchantMapper.ToDomain(request);
        await _repository.SaveAsync(merchant, ct);
        return MerchantMapper.ToResponse(merchant);
    }
}
```

### FluentValidation

```csharp
public class CreateMerchantValidator : AbstractValidator<CreateMerchantRequest>
{
    public CreateMerchantValidator()
    {
        RuleFor(x => x.Mid)
            .NotEmpty().MaximumLength(15);

        RuleFor(x => x.Name)
            .NotEmpty().MaximumLength(100);

        RuleFor(x => x.Document)
            .NotEmpty()
            .Matches(@"^\d{11,14}$")
            .WithMessage("Document must be CPF (11 digits) or CNPJ (14 digits)");

        RuleFor(x => x.Mcc)
            .NotEmpty().Length(4)
            .Matches(@"^\d{4}$");
    }
}
```

### Polly (Resilience)

```csharp
// Retry with exponential backoff
var retryPolicy = Policy
    .Handle<HttpRequestException>()
    .WaitAndRetryAsync(3, attempt =>
        TimeSpan.FromSeconds(Math.Pow(2, attempt)));

// Circuit breaker
var circuitBreaker = Policy
    .Handle<SqlException>()
    .CircuitBreakerAsync(
        exceptionsAllowedBeforeBreaking: 5,
        durationOfBreak: TimeSpan.FromSeconds(30));

// Combined policy
var resilientPolicy = Policy.WrapAsync(retryPolicy, circuitBreaker);
```

## Prohibited

| Library/Pattern     | Reason                                    | Alternative              |
| ------------------- | ----------------------------------------- | ------------------------ |
| NUnit               | Less modern than xUnit                    | xUnit                    |
| MSTest              | Limited features                          | xUnit                    |
| Console.WriteLine   | Unstructured, no levels                   | Serilog / ILogger        |
| Newtonsoft.Json      | System.Text.Json is built-in and faster   | System.Text.Json         |
| log4net             | Legacy, no structured logging             | Serilog                  |

## Package Management

- **NuGet** with `PackageReference` format in `.csproj`
- Lock file (`packages.lock.json`) committed with `RestorePackagesWithLockFile`
- Central Package Management (`Directory.Packages.props`) for multi-project solutions
- Pin all package versions explicitly

## Security

- Run `dotnet list package --vulnerable` regularly
- No packages with known critical vulnerabilities
- Use `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` in CI
