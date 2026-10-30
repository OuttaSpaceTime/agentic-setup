---
paths:
  - "src/**/*.ts"
---

# TypeScript Conventions

## Strict Migration Phase

This project is in a **strict-mode migration phase**. `tsconfig.strict.json` enforces `strictNullChecks`, `strictBindCallApply`, `strictBuiltinIteratorReturn`, and `useUnknownInCatchVariables`.

- All new code must be strict-compatible
- Every PR must keep the strict error count equal or lower — run `node strict-migrate.mjs` to verify
- If errors decrease, update `CURRENT_ERRORS` in `strict-migrate.mjs` in the same change

## Rely on Inference

Let TypeScript infer types wherever possible — only annotate when inference cannot communicate intent or would widen the type.

**Always infer:**
- `inject()` return types
- Simple literals
- Local variables with obvious types
- RxJS operator chain results when the type is clear

**Always annotate:**
- Public method return types when non-trivial
- Observable type parameters (`BehaviorSubject<MyType>`, `Observable<MyType>`)
- Variables initialized to `null` or with union types
- Complex generic types where inference would be too broad

<example>

```typescript
// ✅ Infer
private dataService = inject(DataService)
const count = 0
const items = ['a', 'b']

// ✅ Annotate
state$ = new BehaviorSubject<ListState>(initialState)
loadList(params: ListParams): Observable<void> { ... }
let result: Data | null = null
```

</example>

<example type="invalid">

```typescript
private dataService: DataService = inject(DataService)  // ❌ redundant
const count: number = 0                                  // ❌ redundant
```

</example>

## null vs undefined

Use `undefined` (via `?`) for omitted optional values. Use `null` only when the runtime or API contract explicitly requires it.

<example>

```typescript
interface User {
  id: string
  avatar?: string       // omitted = undefined
  deletedAt: Date | null  // explicitly cleared by API
}
```

</example>

<critical>

  Never use `!` non-null assertions or `as any` casts to silence strict errors — fix the underlying type.

</critical>
