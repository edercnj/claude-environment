# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# C# 12 Version Features

## Primary Constructors for Classes and Structs

Declare constructor parameters directly in the class declaration, reducing boilerplate.

```csharp
// OLD - verbose constructor boilerplate
public class MerchantService
{
    private readonly IMerchantRepository _repository;
    private readonly ILogger<MerchantService> _logger;

    public MerchantService(IMerchantRepository repository, ILogger<MerchantService> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<Merchant?> FindByMidAsync(string mid)
    {
        _logger.LogInformation("Finding merchant {Mid}", mid);
        return await _repository.FindByMidAsync(mid);
    }
}

// NEW (C# 12) - primary constructor
public class MerchantService(
    IMerchantRepository repository,
    ILogger<MerchantService> logger)
{
    public async Task<Merchant?> FindByMidAsync(string mid)
    {
        logger.LogInformation("Finding merchant {Mid}", mid);
        return await repository.FindByMidAsync(mid);
    }
}
```

### With Validation

```csharp
public class AmountCents(long value)
{
    public long Value { get; } = value >= 0
        ? value
        : throw new ArgumentOutOfRangeException(nameof(value), "Amount must be non-negative");

    public decimal ToDecimal() => Value / 100m;
}

// Struct with primary constructor
public readonly struct MerchantId(string value)
{
    public string Value { get; } = !string.IsNullOrWhiteSpace(value)
        ? value
        : throw new ArgumentException("MID must not be blank", nameof(value));

    public override string ToString() => Value;
}
```

### Dependency Injection Pattern

```csharp
// Clean DI with primary constructors
public class TransactionHandler(
    ICentsDecisionEngine engine,
    IMerchantRepository merchantRepo,
    ITransactionRepository transactionRepo,
    ILogger<TransactionHandler> logger)
{
    public async Task<TransactionResult> ProcessAsync(IsoMessage request)
    {
        var merchant = await merchantRepo.FindByMidAsync(request.MerchantId)
            ?? throw new MerchantNotFoundException(request.MerchantId);

        var decision = engine.Decide(request.Amount);
        logger.LogInformation("Decision: {RC} for MTI {Mti}", decision.ResponseCode, request.Mti);

        var transaction = TransactionMapper.ToDomain(request, decision);
        await transactionRepo.SaveAsync(transaction);

        return TransactionMapper.ToResult(request, decision);
    }
}
```

## Collection Expressions

New concise syntax for creating collections.

```csharp
// OLD
var numbers = new List<int> { 1, 2, 3, 4, 5 };
var names = new string[] { "Alice", "Bob", "Charlie" };
var empty = Array.Empty<int>();
var span = new ReadOnlySpan<byte>(new byte[] { 0x00, 0xC8 });

// NEW (C# 12)
List<int> numbers = [1, 2, 3, 4, 5];
string[] names = ["Alice", "Bob", "Charlie"];
int[] empty = [];
ReadOnlySpan<byte> span = [0x00, 0xC8];

// Spread operator
int[] first = [1, 2, 3];
int[] second = [4, 5, 6];
int[] combined = [..first, ..second]; // [1, 2, 3, 4, 5, 6]

// Practical: building response lists
List<string> validMccs = ["5411", "5812", "5912", "7011"];

List<MerchantResponse> responses = [
    ..activeMerchants.Select(MerchantMapper.ToResponse),
    ..pendingMerchants.Select(MerchantMapper.ToResponse),
];
```

### Collection Expression Targets

```csharp
// Works with various collection types
List<int> list = [1, 2, 3];
int[] array = [1, 2, 3];
Span<int> span = [1, 2, 3];
ReadOnlySpan<int> roSpan = [1, 2, 3];
ImmutableArray<int> immutable = [1, 2, 3];

// Empty collections
List<Merchant> merchants = [];
Dictionary<string, int> counts = []; // Not yet supported for Dictionary
```

## Inline Arrays

High-performance fixed-size buffers without `unsafe` code.

```csharp
[InlineArray(16)]
public struct HexBuffer
{
    private byte _element;
}

// Usage
var buffer = new HexBuffer();
buffer[0] = 0xFF;

// Practical: fixed-size bitmap buffer for ISO 8583
[InlineArray(8)]
public struct BitmapBuffer
{
    private byte _element;
}

public static BitmapBuffer ParseBitmap(ReadOnlySpan<byte> data)
{
    var bitmap = new BitmapBuffer();
    data[..8].CopyTo(bitmap);
    return bitmap;
}
```

## `nameof` in Attributes

Use `nameof` to reference parameters and type parameters in attributes.

```csharp
// OLD - hardcoded string
[return: NotNullIfNotNull("input")]
public string? Transform(string? input) => input?.ToUpper();

// NEW (C# 12) - nameof in attribute
[return: NotNullIfNotNull(nameof(input))]
public string? Transform(string? input) => input?.ToUpper();

// With generic type parameters
public class Repository<[DynamicallyAccessedMembers(DynamicallyAccessedMemberTypes.PublicProperties)] TEntity>
    where TEntity : class
{
    // nameof(TEntity) works in attributes
}

// Practical: validation attributes
public record CreateMerchantRequest(
    [property: Required, StringLength(15, ErrorMessage = $"{nameof(Mid)} max 15 chars")]
    string Mid,

    [property: Required, StringLength(100)]
    string Name
);
```

## Interceptors (Preview)

Source generators can intercept method calls at compile time.

```csharp
// Interceptors are a preview feature for source generators
// They allow compile-time replacement of method calls

// Example: a source generator intercepts logging calls
// to add compile-time context (file, line, method)

// Usage is primarily for framework/library authors
// Application code benefits indirectly through improved
// source-generated code (e.g., System.Text.Json, EF Core)

// Enable in .csproj:
// <InterceptorsPreviewNamespaces>$(InterceptorsPreviewNamespaces);MyGenerator</InterceptorsPreviewNamespaces>
```

## Improved Pattern Matching

```csharp
// List patterns (C# 11, enhanced in 12)
public string DescribeList(int[] items) => items switch
{
    [] => "Empty",
    [var single] => $"Single: {single}",
    [var first, .., var last] => $"From {first} to {last}",
};

// Combined with primary constructors
public class ResponseHandler(ILogger<ResponseHandler> logger)
{
    public string Classify(TransactionResult result) => result switch
    {
        { ResponseCode: "00", Amount: > 0 } => "Approved purchase",
        { ResponseCode: "00", Amount: 0 } => "Approved zero-amount",
        { ResponseCode: var rc } when rc.StartsWith("0") => "Soft decline",
        { ResponseCode: "51" or "55" or "61" } => "Hard decline",
        { ResponseCode: "96" } => "System error",
        _ => "Unknown"
    };
}
```

## Recommended .csproj Settings (C# 12)

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
    <PropertyGroup>
        <TargetFramework>net8.0</TargetFramework>
        <LangVersion>12.0</LangVersion>
        <Nullable>enable</Nullable>
        <ImplicitUsings>enable</ImplicitUsings>
        <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
        <AnalysisLevel>latest-recommended</AnalysisLevel>
        <EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
    </PropertyGroup>
</Project>
```

## Default Lambda Parameters (C# 12)

```csharp
// Lambda parameters can now have default values
var addTax = (decimal price, decimal rate = 0.1m) => price * (1 + rate);

var total = addTax(100m);        // 110.0 (uses default rate)
var custom = addTax(100m, 0.2m); // 120.0 (custom rate)

// Practical: configurable filters
Func<Transaction, bool> createFilter = (
    Transaction tx,
    string? mti = null,
    string? rc = null) =>
{
    if (mti is not null && tx.Mti != mti) return false;
    if (rc is not null && tx.ResponseCode != rc) return false;
    return true;
};
```
