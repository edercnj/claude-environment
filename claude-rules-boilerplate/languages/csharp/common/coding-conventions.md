# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# C# Coding Conventions

## Style Enforcement

- **.editorconfig** for consistent formatting
- **Roslyn analyzers** for code quality
- Nullable reference types (NRT) enabled: `<Nullable>enable</Nullable>`

## Naming Conventions

| Element           | Convention     | Example                    |
| ----------------- | -------------- | -------------------------- |
| Class             | PascalCase     | `OrderProcessor`           |
| Interface         | IPascalCase    | `IMerchantRepository`      |
| Method            | PascalCase     | `ProcessOrder()`           |
| Property          | PascalCase     | `MerchantName`             |
| Parameter         | camelCase      | `merchantId`               |
| Local variable    | camelCase      | `orderTotal`               |
| Private field     | _camelCase     | `_repository`              |
| Constant          | PascalCase     | `MaxRetryCount`            |
| Enum              | PascalCase     | `OrderStatus`              |
| Enum Member       | PascalCase     | `Pending`, `Approved`      |
| Namespace         | PascalCase     | `Company.Project.Domain`   |
| Type Parameter    | TPascalCase    | `TEntity`, `TResult`       |

## Records for DTOs

```csharp
// CORRECT - record for immutable DTOs
public record MerchantResponse(
    long Id,
    string Mid,
    string Name,
    string DocumentMasked,
    string Status,
    DateTimeOffset CreatedAt
);

public record CreateMerchantRequest(
    string Mid,
    string Name,
    string Document,
    string Mcc,
    bool TimeoutEnabled = false
);

// Record with validation
public record CreateOrderRequest(
    string MerchantId,
    decimal Amount,
    string Currency
)
{
    public void Validate()
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(MerchantId);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(Amount);
    }
}
```

## Nullable Reference Types

```csharp
// NRT enabled - explicit nullability
public interface IMerchantRepository
{
    Task<Merchant?> FindByMidAsync(string mid, CancellationToken ct = default);
    Task<Merchant> GetByIdAsync(long id, CancellationToken ct = default);
    Task SaveAsync(Merchant merchant, CancellationToken ct = default);
}

// Null checking
public async Task<MerchantResponse> GetMerchantAsync(string mid)
{
    var merchant = await _repository.FindByMidAsync(mid)
        ?? throw new MerchantNotFoundException(mid);
    return MerchantMapper.ToResponse(merchant);
}
```

## LINQ for Collections

```csharp
// CORRECT - LINQ for collection operations
var activeMerchants = merchants
    .Where(m => m.Status == MerchantStatus.Active)
    .OrderBy(m => m.Name)
    .Select(MerchantMapper.ToResponse)
    .ToList();

var merchantsByMcc = merchants
    .GroupBy(m => m.Mcc)
    .ToDictionary(g => g.Key, g => g.Count());

var totalAmount = transactions
    .Where(t => t.ResponseCode == "00")
    .Sum(t => t.AmountCents);
```

## Pattern Matching

```csharp
// CORRECT - switch expressions with pattern matching
public string DescribeResult(TransactionResult result) => result switch
{
    { ResponseCode: "00" } => "Approved",
    { ResponseCode: "05" } => "Generic Error",
    { ResponseCode: "14" } => "Invalid Card",
    { ResponseCode: "51" } => "Insufficient Funds",
    { ResponseCode: "96" } => "System Error",
    _ => $"Unknown: {result.ResponseCode}"
};

// Type pattern matching
public IActionResult HandleException(Exception ex) => ex switch
{
    MerchantNotFoundException e => NotFound(ProblemDetail.NotFound(e.Message)),
    MerchantAlreadyExistsException e => Conflict(ProblemDetail.Conflict(e.Message)),
    ValidationException e => BadRequest(ProblemDetail.ValidationError(e.Errors)),
    _ => StatusCode(500, ProblemDetail.InternalError())
};
```

## Resource Management

```csharp
// CORRECT - IAsyncDisposable for async resources
public class DatabaseConnection : IAsyncDisposable
{
    private readonly NpgsqlConnection _connection;

    public async ValueTask DisposeAsync()
    {
        await _connection.DisposeAsync();
        GC.SuppressFinalize(this);
    }
}

// Using declaration (C# 8+)
await using var connection = new DatabaseConnection(connectionString);
var result = await connection.QueryAsync<Merchant>(sql);
```

## Async Operations

```csharp
// CORRECT - async/await with CancellationToken
public async Task<MerchantResponse> CreateMerchantAsync(
    CreateMerchantRequest request,
    CancellationToken cancellationToken = default)
{
    var existing = await _repository.FindByMidAsync(request.Mid, cancellationToken);
    if (existing is not null)
    {
        throw new MerchantAlreadyExistsException(request.Mid);
    }

    var merchant = MerchantMapper.ToDomain(request);
    await _repository.SaveAsync(merchant, cancellationToken);
    return MerchantMapper.ToResponse(merchant);
}

// CORRECT - ValueTask for hot paths
public ValueTask<Merchant?> GetCachedMerchantAsync(string mid)
{
    if (_cache.TryGetValue(mid, out var merchant))
    {
        return ValueTask.FromResult<Merchant?>(merchant);
    }
    return new ValueTask<Merchant?>(FetchAndCacheAsync(mid));
}
```

## String Interpolation

```csharp
// CORRECT - string interpolation
var message = $"Merchant {merchant.Mid} created successfully";
var masked = $"{document[..3]}****{document[^2..]}";

// Raw string literals for complex content
var query = """
    SELECT id, mid, name, status
    FROM merchants
    WHERE mid = @mid
    AND status = 'ACTIVE'
    """;
```

## Extension Methods

```csharp
public static class StringExtensions
{
    public static string MaskDocument(this string document)
    {
        if (document.Length < 5) return "****";
        return $"{document[..3]}****{document[^2..]}";
    }
}

public static class EnumerableExtensions
{
    public static PaginatedResponse<T> ToPaginatedResponse<T>(
        this IEnumerable<T> items, int page, int limit, long total)
    {
        return new PaginatedResponse<T>(items.ToList(), page, limit, total);
    }
}
```

## Size Limits

- Max **25 lines** per method
- Max **250 lines** per file
- Max **4 parameters** per method (use record/class for more)

## Anti-Patterns (FORBIDDEN)

- `Console.WriteLine` for application logging (use Serilog/ILogger)
- Returning `null` from methods that should return collections (return empty)
- `async void` methods (except event handlers)
- Blocking async calls with `.Result` or `.Wait()`
- `catch (Exception)` without re-throwing or specific handling
- Magic strings/numbers without constants
- Mutable public fields (use properties)
