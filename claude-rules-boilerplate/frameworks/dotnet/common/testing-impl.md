# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# .NET — Testing Patterns

## xUnit with WebApplicationFactory

```csharp
public class MerchantApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public MerchantApiTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<AppDbContext>();
                services.AddDbContext<AppDbContext>(options =>
                    options.UseInMemoryDatabase("TestDb"));
            });
        }).CreateClient();
    }

    [Fact]
    public async Task CreateMerchant_ValidRequest_Returns201()
    {
        var request = new { mid = "123456789012345", name = "Test", document = "12345678000190", mcc = "5411" };

        var response = await _client.PostAsJsonAsync("/api/v1/merchants", request);

        response.StatusCode.Should().Be(HttpStatusCode.Created);
        var merchant = await response.Content.ReadFromJsonAsync<MerchantResponse>();
        merchant!.Mid.Should().Be("123456789012345");
    }

    [Fact]
    public async Task GetMerchant_NotFound_Returns404()
    {
        var response = await _client.GetAsync("/api/v1/merchants/99999");

        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
        var problem = await response.Content.ReadFromJsonAsync<ProblemDetails>();
        problem!.Type.Should().Be("/errors/not-found");
    }

    [Fact]
    public async Task CreateMerchant_InvalidBody_Returns400()
    {
        var request = new { mid = "", name = "" };

        var response = await _client.PostAsJsonAsync("/api/v1/merchants", request);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }
}
```

## Unit Tests with NSubstitute

```csharp
public class MerchantServiceTests
{
    private readonly IMerchantRepository _repository;
    private readonly MerchantService _service;

    public MerchantServiceTests()
    {
        _repository = Substitute.For<IMerchantRepository>();
        _service = new MerchantService(_repository, Substitute.For<ILogger<MerchantService>>());
    }

    [Fact]
    public async Task FindById_ExistingId_ReturnsMerchant()
    {
        var entity = new MerchantEntity { Id = 1, Mid = "123", Name = "Store" };
        _repository.FindByIdAsync(1).Returns(entity);

        var result = await _service.FindByIdAsync(1);

        result.Mid.Should().Be("123");
        await _repository.Received(1).FindByIdAsync(1);
    }

    [Fact]
    public async Task FindById_NonExistingId_ThrowsNotFoundException()
    {
        _repository.FindByIdAsync(999).Returns((MerchantEntity?)null);

        var act = () => _service.FindByIdAsync(999);

        await act.Should().ThrowAsync<MerchantNotFoundException>()
            .WithMessage("*999*");
    }

    [Fact]
    public async Task Create_DuplicateMid_ThrowsConflict()
    {
        _repository.FindByMidAsync("123").Returns(new MerchantEntity { Mid = "123" });
        var request = new CreateMerchantRequest("123", "New", "12345678000190", "5411");

        var act = () => _service.CreateAsync(request);

        await act.Should().ThrowAsync<MerchantAlreadyExistsException>();
    }
}
```

## FluentAssertions

```csharp
// Collection assertions
merchants.Should().HaveCount(3);
merchants.Should().ContainSingle(m => m.Mid == "123");
merchants.Should().BeInDescendingOrder(m => m.CreatedAt);

// Object assertions
merchant.Should().BeEquivalentTo(expected, options => options.Excluding(m => m.CreatedAt));

// Exception assertions
act.Should().ThrowAsync<AppException>().WithMessage("*not found*");
```

## Test Data Builders

```csharp
public static class MerchantFixture
{
    public static MerchantEntity AnEntity(string mid = "123456789012345") => new()
    {
        Id = 1, Mid = mid, Name = "Test Store", Document = "12345678000190",
        Mcc = "5411", Status = "ACTIVE", CreatedAt = DateTimeOffset.UtcNow,
    };

    public static CreateMerchantRequest ACreateRequest(string? mid = null) => new(
        Mid: mid ?? $"MID{DateTime.UtcNow.Ticks % 1_000_000_000}",
        Name: "Test Store", Document: "12345678000190", Mcc: "5411"
    );
}
```

## Naming Convention

```
[MethodUnderTest]_[Scenario]_[ExpectedBehavior]
```

Examples: `FindById_ExistingId_ReturnsMerchant`, `Create_DuplicateMid_ThrowsConflict`

## Anti-Patterns

- Do NOT use `Assert.Equal` -- use FluentAssertions for readable assertions
- Do NOT use Moq -- prefer NSubstitute for cleaner syntax
- Do NOT test with real databases in unit tests -- use InMemoryDatabase or mocks
- Do NOT share test state between test methods -- each test must be independent
- Do NOT skip error path testing -- validate all ProblemDetails responses
