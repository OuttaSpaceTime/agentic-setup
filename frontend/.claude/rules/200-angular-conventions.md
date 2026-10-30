---
paths:
  - "src/**/*.ts"
  - "src/**/*.html"
---

# Angular Project Conventions

## Project Structure

| Directory | Purpose |
|-----------|---------|
| `src/app/core/` | Vilocify-specific app-wide code: auth, interceptors, global state, app guards |
| `src/app/features/` | Feature flows, typically mapping to sidebar nav items |
| `src/app/shared/` | Generic reusable code: UI components, pipes, directives, validators usable in any Angular app |

<example>

```
core/services/authentication.service.ts   ✅ app-specific
features/dashboard/dashboard.component.ts ✅ feature
shared/components/button/button.component.ts ✅ generic UI
```

</example>

<example type="invalid">

```
shared/services/authentication.service.ts  ❌ app-specific → core
core/components/button.component.ts        ❌ generic UI → shared
```

</example>

## Dependency Injection

Always use `inject()` — never constructor injection.

<example>

```typescript
export class MyComponent {
  private dataService = inject(DataService);
  private destroyRef = inject(DestroyRef);
}
```

</example>

<example type="invalid">

```typescript
export class MyComponent {
  constructor(private dataService: DataService) {}
}
```

</example>

## Components

- Always set `changeDetection: ChangeDetectionStrategy.OnPush`
- Use `@if`, `@for`, `@switch` — never `*ngIf`, `*ngFor`
- Use single `async` pipe at template root; avoid multiple async pipes for the same observable

<example>

```typescript
@Component({
  selector: 'app-feature',
  templateUrl: './feature.component.html',
  styleUrl: './feature.component.css',
  changeDetection: ChangeDetectionStrategy.OnPush
})
```

</example>

## Service State Design

Expose a **single state observable** with raw data. Compute derived/formatted values in component methods — never in the state observable.

<example>

```typescript
// ✅ Service: single state, raw data only
membershipLimitState$ = this.session$.pipe(
  map(session => ({
    canEdit: session.hasPermission('write:memberships'),
    current: session.currentCount,
    limit: session.maxCount
  }))
);

// ✅ Component: derive on-demand
warningMessage(current: number, limit: number): string | null {
  if (!current || !limit) return null;
  return `${current} of ${limit} used`;
}
```

</example>

<example type="invalid">

```typescript
// ❌ Multiple derived observables in service
canEdit$ = this.session$.pipe(map(s => s.hasPermission('write:memberships')));
current$ = this.session$.pipe(map(s => s.currentCount));

// ❌ Derived values added to state
membershipLimitState$ = this.session$.pipe(
  map(session => ({
    current: session.currentCount,
    warning: this.formatWarning(session.currentCount) // ❌ computed
  }))
);
```

</example>
