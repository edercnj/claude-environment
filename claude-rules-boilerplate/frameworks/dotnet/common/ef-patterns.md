# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# .NET — Entity Framework Core Patterns
> Extends: `core/11-database-principles.md`

## DbContext

```csharp
public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<MerchantEntity> Merchants => Set<MerchantEntity>();
    public DbSet<TerminalEntity> Terminals => Set<TerminalEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema("simulator");
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}
```

## Entity Configuration

```csharp
public class MerchantEntity
{
    public long Id { get; set; }
    public string Mid { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Document { get; set; } = string.Empty;
    public string Mcc { get; set; } = string.Empty;
    public string Status { get; set; } = "ACTIVE";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public ICollection<TerminalEntity> Terminals { get; set; } = new List<TerminalEntity>();
}

public class MerchantEntityConfiguration : IEntityTypeConfiguration<MerchantEntity>
{
    public void Configure(EntityTypeBuilder<MerchantEntity> builder)
    {
        builder.ToTable("merchants");
        builder.HasKey(m => m.Id);
        builder.Property(m => m.Mid).HasMaxLength(15).IsRequired();
        builder.HasIndex(m => m.Mid).IsUnique();
        builder.Property(m => m.Name).HasMaxLength(100).IsRequired();
        builder.Property(m => m.Document).HasMaxLength(14).IsRequired();
        builder.Property(m => m.Mcc).HasMaxLength(4).IsRequired();
        builder.Property(m => m.Status).HasMaxLength(20).HasDefaultValue("ACTIVE");
        builder.Property(m => m.CreatedAt).HasDefaultValueSql("NOW()");
        builder.Property(m => m.UpdatedAt).HasDefaultValueSql("NOW()");
        builder.HasMany(m => m.Terminals).WithOne(t => t.Merchant).HasForeignKey(t => t.MerchantId);
    }
}
```

## Repository Pattern

```csharp
public class MerchantRepository : IMerchantRepository
{
    private readonly AppDbContext _context;

    public MerchantRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<MerchantEntity?> FindByIdAsync(long id)
    {
        return await _context.Merchants.FindAsync(id);
    }

    public async Task<MerchantEntity?> FindByMidAsync(string mid)
    {
        return await _context.Merchants.FirstOrDefaultAsync(m => m.Mid == mid);
    }

    public async Task<MerchantEntity> CreateAsync(MerchantEntity entity)
    {
        _context.Merchants.Add(entity);
        await _context.SaveChangesAsync();
        return entity;
    }

    public async Task<(List<MerchantEntity> Items, int Total)> PaginateAsync(int page, int limit)
    {
        var total = await _context.Merchants.CountAsync();
        var items = await _context.Merchants
            .OrderByDescending(m => m.CreatedAt)
            .Skip(page * limit)
            .Take(limit)
            .ToListAsync();
        return (items, total);
    }
}
```

## Migrations

```bash
# Create migration
dotnet ef migrations add AddMerchantTable

# Apply
dotnet ef database update

# Generate SQL script
dotnet ef migrations script
```

## LINQ Queries

```csharp
// Filtered query with projection
var results = await _context.Merchants
    .Where(m => m.Status == "ACTIVE" && m.Mcc == "5411")
    .Select(m => new MerchantResponse(m.Id, m.Mid, m.Name, MaskDocument(m.Document), m.Mcc, m.Status, m.CreatedAt))
    .ToListAsync();

// Eager loading
var merchant = await _context.Merchants
    .Include(m => m.Terminals)
    .FirstOrDefaultAsync(m => m.Id == id);
```

## Anti-Patterns

- Do NOT register `DbContext` as Singleton -- use Scoped lifetime
- Do NOT expose `DbContext` outside the repository layer
- Do NOT use `Find()` for queries with includes -- use `FirstOrDefaultAsync()` with `Include()`
- Do NOT call `SaveChangesAsync()` multiple times per unit of work
- Do NOT modify applied migrations in production -- create new ones
- Do NOT use `float`/`double` for monetary values -- use `decimal` or `long` (cents)
