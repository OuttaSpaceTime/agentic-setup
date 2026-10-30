---
paths:
  - "src/**/*.service.ts"
  - "src/**/*.component.ts"
  - "src/**/*.interceptor.ts"
  - "src/app/shared/operators/**"
---

# HTTP Error Handling

## Default Behaviour

The `redirectOnServerError` interceptor handles 5xx errors, timeouts, and network errors **globally** by redirecting to `/500`. This runs for all requests by default.

## Opting Out: CUSTOM_ERROR_HANDLING

When a service needs to handle errors itself (e.g. show inline error state instead of redirecting), set the `CUSTOM_ERROR_HANDLING` context token on the request.

<example>

```typescript
import { HttpContext } from '@angular/common/http'
import { CUSTOM_ERROR_HANDLING } from '@core/contexts/custom-error-handling.context'
import { withRequestState } from '@shared/operators/with-request-state'

// In a service method:
this.httpClient.get('/api/data', {
  context: new HttpContext().set(CUSTOM_ERROR_HANDLING, true)
}).pipe(withRequestState())
```

</example>

<example type="invalid">

```typescript
// ❌ No context — interceptor redirects to /500 on error, withRequestState never sees it
this.httpClient.get('/api/data').pipe(withRequestState())
```

</example>

## withRequestState()

Use `withRequestState()` from `@shared/operators/with-request-state` to convert an HTTP observable into a loading/success/error state object for template binding. Always pair it with `CUSTOM_ERROR_HANDLING`.

```typescript
// Returns Observable<RequestState<T>> with shape: { loading, data?, error? }
state$ = this.httpClient.get<Data[]>('/api/items', {
  context: new HttpContext().set(CUSTOM_ERROR_HANDLING, true)
}).pipe(withRequestState())
```

```html
@if (state$ | async; as state) {
  @if (state.loading) { <app-spinner /> }
  @if (state.error)   { <p>Something went wrong</p> }
  @if (state.data)    { <app-list [items]="state.data" /> }
}
```

<critical>

  `withRequestState()` is for singular fetch requests only — not for long-lived subscriptions. It does not resubscribe on error.

</critical>

## JsonApiClientService Base Methods

Services extending `JsonApiClientService` can pass context through the optional `context` parameter:

```typescript
this.crud.index(params, new HttpContext().set(CUSTOM_ERROR_HANDLING, true))
  .pipe(withRequestState())
```

## When to Use Each

| Scenario | Pattern |
|----------|---------|
| General data fetch, failure = hard error | Default (no context) — interceptor redirects |
| Inline error state in UI | `CUSTOM_ERROR_HANDLING: true` + `withRequestState()` |
| Polled/retried requests | `CUSTOM_ERROR_HANDLING: true` + manual `catchError` |
