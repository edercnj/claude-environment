# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# NestJS — Prisma Patterns

## PrismaService

Wrap Prisma Client as a NestJS injectable with lifecycle hooks:

```typescript
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit(): Promise<void> {
    await this.$connect();
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
```

Register in a shared module:

```typescript
@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
```

## Repository Pattern over Prisma

```typescript
@Injectable()
export class MerchantRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findById(id: number): Promise<Merchant | null> {
    return this.prisma.merchant.findUnique({ where: { id } });
  }

  async findByMid(mid: string): Promise<Merchant | null> {
    return this.prisma.merchant.findUnique({ where: { mid } });
  }

  async create(data: CreateMerchantInput): Promise<Merchant> {
    return this.prisma.merchant.create({ data });
  }

  async paginate(page: number, limit: number): Promise<[Merchant[], number]> {
    const [data, total] = await this.prisma.$transaction([
      this.prisma.merchant.findMany({ skip: page * limit, take: limit, orderBy: { createdAt: 'desc' } }),
      this.prisma.merchant.count(),
    ]);
    return [data, total];
  }
}
```

## Migrations

```bash
# Create migration
npx prisma migrate dev --name add_merchant_table

# Apply in production
npx prisma migrate deploy

# Generate client after schema change
npx prisma generate
```

## Schema Example

```prisma
model Merchant {
  id        Int      @id @default(autoincrement())
  mid       String   @unique @db.VarChar(15)
  name      String   @db.VarChar(100)
  document  String   @db.VarChar(14)
  mcc       String   @db.VarChar(4)
  status    String   @default("ACTIVE") @db.VarChar(20)
  createdAt DateTime @default(now()) @map("created_at")
  updatedAt DateTime @updatedAt @map("updated_at")
  terminals Terminal[]

  @@map("merchants")
}
```

## Transactions

```typescript
async transferWithAudit(from: number, to: number, amount: number): Promise<void> {
  await this.prisma.$transaction(async (tx) => {
    await tx.account.update({ where: { id: from }, data: { balance: { decrement: amount } } });
    await tx.account.update({ where: { id: to }, data: { balance: { increment: amount } } });
    await tx.auditLog.create({ data: { fromId: from, toId: to, amount } });
  });
}
```

## Anti-Patterns

- Do NOT use `PrismaClient` directly in controllers -- always go through a repository or service
- Do NOT skip `$disconnect()` -- use `OnModuleDestroy` lifecycle hook
- Do NOT write raw SQL unless Prisma query API is insufficient -- prefer type-safe queries
- Do NOT ignore migration drift -- always run `prisma migrate dev` during development
