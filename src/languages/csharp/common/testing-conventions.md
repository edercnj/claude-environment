# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# C# Testing Conventions

## Framework

- **xUnit** as test framework
- **FluentAssertions** for assertions
- **NSubstitute** or **Moq** for mocking

## Coverage Thresholds

| Metric          | Minimum |
| --------------- | ------- |
| Line Coverage   | >= 95%  |
| Branch Coverage | >= 90%  |

## Naming Convention

```
MethodName_Scenario_ExpectedBehavior
```

```csharp
[Fact]
public async Task FindByMid_ExistingMerchant_ReturnsMerchant() { ... }

[Fact]
public async Task FindByMid_NonexistentMid_ReturnsNull() { ... }

[Fact]
public async Task CreateMerchant_DuplicateMid_ThrowsAlreadyExistsException() { ... }
```

## Test Structure (Arrange-Act-Assert)

```csharp
public class MerchantServiceTests
{
    private readonly IMerchantRepository _repository;
    private readonly MerchantService _service;

    public MerchantServiceTests()
    {
        _repository = Substitute.For<IMerchantRepository>();
        _service = new MerchantService(_repository);
    }

    [Fact]
    public async Task CreateMerchant_ValidPayload_ReturnsMerchant()
    {
        // Arrange
        var request = new CreateMerchantRequest("MID001", "Test Store", "12345678000190", "5411");
        _repository.FindByMidAsync("MID001").Returns((Merchant?)null);

        // Act
        var result = await _service.CreateMerchantAsync(request);

        // Assert
        result.Mid.Should().Be("MID001");
        result.Status.Should().Be("ACTIVE");
        await _repository.Received(1).SaveAsync(Arg.Any<Merchant>(), Arg.Any<CancellationToken>());
    }
}
```

## FluentAssertions

```csharp
using FluentAssertions;

[Fact]
public async Task FindAll_ReturnsPaginatedMerchants()
{
    var result = await _service.FindAllAsync(page: 0, limit: 10);

    result.Data.Should().HaveCount(5);
    result.Pagination.Total.Should().Be(5);
    result.Data.Should().AllSatisfy(m =>
        m.Status.Should().Be("ACTIVE")
    );
}

[Fact]
public async Task CreateMerchant_DuplicateMid_ThrowsWithMessage()
{
    var act = () => _service.CreateMerchantAsync(duplicateRequest);

    await act.Should()
        .ThrowAsync<MerchantAlreadyExistsException>()
        .WithMessage("*MID001*");
}

[Fact]
public void MaskDocument_ValidCnpj_MasksMiddle()
{
    var result = "12345678000190".MaskDocument();

    result.Should().StartWith("123");
    result.Should().EndWith("90");
    result.Should().Contain("****");
}
```

## NSubstitute (Mocking)

```csharp
using NSubstitute;

public class OrderServiceTests
{
    private readonly IPaymentGateway _gateway;
    private readonly OrderService _service;

    public OrderServiceTests()
    {
        _gateway = Substitute.For<IPaymentGateway>();
        _service = new OrderService(_gateway);
    }

    [Fact]
    public async Task ProcessOrder_ValidOrder_CallsGatewayWithCorrectAmount()
    {
        // Arrange
        var order = OrderFixture.CreateOrder(amount: 100.00m);
        _gateway.ChargeAsync(Arg.Any<decimal>(), Arg.Any<string>())
            .Returns(new PaymentResult { Success = true });

        // Act
        await _service.ProcessAsync(order);

        // Assert
        await _gateway.Received(1)
            .ChargeAsync(100.00m, "BRL");
    }

    [Fact]
    public async Task ProcessOrder_GatewayFails_ThrowsProcessingException()
    {
        _gateway.ChargeAsync(Arg.Any<decimal>(), Arg.Any<string>())
            .ThrowsAsync(new GatewayException("Connection refused"));

        var act = () => _service.ProcessAsync(OrderFixture.CreateOrder());

        await act.Should().ThrowAsync<ProcessingException>();
    }
}
```

## Parametrized Tests

```csharp
[Theory]
[InlineData("100.00", "00", "Approved")]
[InlineData("100.51", "51", "Insufficient Funds")]
[InlineData("100.05", "05", "Generic Error")]
[InlineData("100.14", "14", "Invalid Card")]
[InlineData("100.43", "43", "Stolen Card")]
public void CentsRule_VariousAmounts_ReturnsCorrectResponseCode(
    string amount, string expectedRc, string description)
{
    var engine = new CentsDecisionEngine();
    var result = engine.Decide(decimal.Parse(amount));

    result.ResponseCode.Should().Be(expectedRc, because: description);
}
```

## API Testing with WebApplicationFactory

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
                services.AddScoped<IMerchantRepository, InMemoryMerchantRepository>();
            });
        }).CreateClient();
    }

    [Fact]
    public async Task CreateMerchant_ValidPayload_Returns201()
    {
        var request = new CreateMerchantRequest("MID001", "Test", "12345678000190", "5411");
        var response = await _client.PostAsJsonAsync("/api/v1/merchants", request);

        response.StatusCode.Should().Be(HttpStatusCode.Created);
        var body = await response.Content.ReadFromJsonAsync<MerchantResponse>();
        body!.Mid.Should().Be("MID001");
    }

    [Fact]
    public async Task GetMerchant_Nonexistent_Returns404()
    {
        var response = await _client.GetAsync("/api/v1/merchants/99999");
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }
}
```

## Test Fixtures

```csharp
public static class MerchantFixture
{
    public static Merchant CreateMerchant(
        string mid = "MID000000000001",
        string name = "Test Store",
        MerchantStatus status = MerchantStatus.Active)
    {
        return new Merchant
        {
            Id = 1,
            Mid = mid,
            Name = name,
            Document = "12345678000190",
            Mcc = "5411",
            Status = status,
            CreatedAt = DateTimeOffset.Parse("2026-01-01T00:00:00Z"),
        };
    }

    public static CreateMerchantRequest CreateRequest(string mid = "MID000000000001")
    {
        return new CreateMerchantRequest(mid, "Test Store", "12345678000190", "5411");
    }
}
```

## Anti-Patterns

- Using NUnit or MSTest (use xUnit)
- `Assert.AreEqual` instead of FluentAssertions
- Tests depending on execution order
- `Thread.Sleep` in async tests (use `Task.Delay` or mock time)
- Tests without assertions
- Mocking value types or records
- `async void` test methods
