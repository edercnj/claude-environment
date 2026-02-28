# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# TypeScript 5.x Version Features

## `satisfies` Operator

Type-checks a value against a type without widening the inferred type.

```typescript
type ColorMap = Record<string, string | number[]>;

// CORRECT - satisfies preserves the narrowed type
const colors = {
    red: "#ff0000",
    green: [0, 255, 0],
} satisfies ColorMap;

// `colors.red` is inferred as `string`, not `string | number[]`
colors.red.toUpperCase(); // Works
colors.green.map((v) => v * 2); // Works

// Without satisfies, this would be `string | number[]`
const colorsOld: ColorMap = { red: "#ff0000", green: [0, 255, 0] };
// colorsOld.red.toUpperCase(); // Error: might be number[]
```

### Use Cases

```typescript
// Configuration objects with known structure
const config = {
    port: 8080,
    host: "localhost",
    debug: false,
} satisfies Record<string, string | number | boolean>;

// Route definitions
const routes = {
    home: "/",
    merchants: "/api/v1/merchants",
    terminals: "/api/v1/terminals",
} satisfies Record<string, string>;
```

## `const` Type Parameters

Infer literal types from generic arguments without requiring `as const`.

```typescript
// Without const type parameter
function createRoute<T extends string[]>(paths: T): T {
    return paths;
}
const routes = createRoute(["home", "about"]); // string[]

// CORRECT - with const type parameter
function createRouteConst<const T extends string[]>(paths: T): T {
    return paths;
}
const routesConst = createRouteConst(["home", "about"]); // readonly ["home", "about"]
```

### Practical Example

```typescript
function defineEndpoints<const T extends Record<string, { method: string; path: string }>>(
    endpoints: T,
): T {
    return endpoints;
}

const api = defineEndpoints({
    listMerchants: { method: "GET", path: "/api/v1/merchants" },
    createMerchant: { method: "POST", path: "/api/v1/merchants" },
});

// api.listMerchants.method is "GET", not string
```

## Decorators (Stage 3)

Standard TC39 decorators, stable and interoperable.

```typescript
function logged(originalMethod: Function, context: ClassMethodDecoratorContext) {
    return function (this: unknown, ...args: unknown[]) {
        console.log(`Calling ${String(context.name)} with`, args);
        const result = originalMethod.apply(this, args);
        console.log(`${String(context.name)} returned`, result);
        return result;
    };
}

class MerchantService {
    @logged
    findByMid(mid: string): Merchant | undefined {
        return this.repository.findByMid(mid);
    }
}
```

### Class Field Decorators

```typescript
function validate(schema: z.ZodType) {
    return function (_: undefined, context: ClassFieldDecoratorContext) {
        return function (initialValue: unknown) {
            return schema.parse(initialValue);
        };
    };
}
```

## `using` Keyword (Explicit Resource Management)

Automatic cleanup via the `Symbol.dispose` protocol.

```typescript
class DatabaseConnection implements Disposable {
    [Symbol.dispose](): void {
        this.close();
    }

    close(): void {
        // Release connection back to pool
    }
}

// CORRECT - automatic disposal at end of scope
function queryMerchant(id: string): Merchant {
    using connection = new DatabaseConnection();
    return connection.query("SELECT * FROM merchants WHERE id = $1", [id]);
    // connection.[Symbol.dispose]() called automatically
}

// Async version
class AsyncFileHandle implements AsyncDisposable {
    async [Symbol.asyncDispose](): Promise<void> {
        await this.close();
    }
}

async function processFile(path: string): Promise<void> {
    await using handle = await openFile(path);
    await handle.write("data");
    // handle.[Symbol.asyncDispose]() called automatically
}
```

## Type Parameter Defaults Improvements

```typescript
// Improved inference with defaults
interface Repository<T, ID = string> {
    findById(id: ID): Promise<T | undefined>;
    save(entity: T): Promise<T>;
    deleteById(id: ID): Promise<void>;
}

// ID defaults to string
class MerchantRepository implements Repository<Merchant> {
    async findById(id: string): Promise<Merchant | undefined> { ... }
}

// Override with number
class LegacyRepository implements Repository<Order, number> {
    async findById(id: number): Promise<Order | undefined> { ... }
}
```

## tsconfig.json Recommended Settings (TS 5.x)

```json
{
    "compilerOptions": {
        "target": "ES2023",
        "module": "NodeNext",
        "moduleResolution": "NodeNext",
        "strict": true,
        "noUncheckedIndexedAccess": true,
        "exactOptionalPropertyTypes": true,
        "noImplicitOverride": true,
        "verbatimModuleSyntax": true,
        "isolatedModules": true,
        "skipLibCheck": true
    }
}
```
