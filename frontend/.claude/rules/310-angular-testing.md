---
paths:
  - "src/**/*.spec.ts"
---

# Angular Testing

## Test Titles

Present tense, behavior-focused. Never use `should`. Skip "creates component/service" tests.

<example>

```typescript
it('displays error message when form is invalid', () => {})
it('emits value when button is clicked', () => {})
```

</example>

<example type="invalid">

```typescript
it('should display error message', () => {})
it('creates the component', () => {})
```

</example>

## Test Data

Use factory functions from `@shared/spec/factories` — never construct models manually.

<example>

```typescript
import { buildMembership } from '@shared/spec/factories/membership.module'
const membership = buildMembership({ role: 'admin' })
```

</example>

## Element Selection

Use `By.css('[data-test-id="..."]')` — never CSS classes. The one exception is markup the spec's own
test host defines, where a class selector is fine.

<example>

```html
<button data-test-id="submit-button">Submit</button>
```
```typescript
const button = fixture.debugElement.query(By.css('[data-test-id="submit-button"]'))
```

</example>

## Standalone Component Setup

Use `overrideComponent` for services listed in the component's own `providers`. Use `configureTestingModule` only for environment-level providers (`provideRouter`, `provideHttpTesting`).

<example>

```typescript
beforeEach(() => {
  mockService = jasmine.createSpyObj<MyService>('MyService', ['getData'])
  TestBed.configureTestingModule({
    providers: [provideRouter([])]
  })
  TestBed.overrideComponent(MyComponent, {
    set: { providers: [{ provide: MyService, useValue: mockService }] }
  })
  fixture = TestBed.createComponent(MyComponent)
})
```

</example>

<example type="invalid">

```typescript
TestBed.configureTestingModule({
  imports: [MyComponent],  // ❌ unnecessary
  providers: [{ provide: MyService, useValue: mockService }]  // ❌ use overrideComponent
})
```

</example>

## Component Inputs

Use `fixture.componentRef.setInput()` — it marks the component for check (OnPush-safe) and makes `ngOnChanges` run on the next `fixture.detectChanges()`.

```typescript
fixture.componentRef.setInput('title', 'New Title')
fixture.detectChanges()
```

## Interceptor Testing

Use `provideHttpClient(withInterceptors([...]))` + `provideHttpClientTesting()`.

<example>

```typescript
beforeEach(() => {
  TestBed.configureTestingModule({
    providers: [
      provideHttpClient(withInterceptors([myInterceptor])),
      provideHttpClientTesting(),
    ]
  })
  httpMock = TestBed.inject(HttpTestingController)
  httpClient = TestBed.inject(HttpClient)
})

afterEach(() => httpMock.verify())
```

</example>

## withRequestState Test Helpers

Use helpers from `@shared/spec/rxjs.module` when testing components that consume `withRequestState()`.

```typescript
import { loadingRequestState, errorRequestState, successRequestState } from '@shared/spec/rxjs.module'

mockService.fetch.and.returnValue(successRequestState(data))
mockService.fetch.and.returnValue(loadingRequestState())
mockService.fetch.and.returnValue(errorRequestState(new Error('failed')))
```

## Async Tests

Prefer `fakeAsync` + `tick()`. Never call `fixture.detectChanges()` in `beforeEach` for async/fakeAsync tests — call it inside the test body.

<example>

```typescript
it('updates view after async task', fakeAsync(() => {
  fixture.detectChanges()
  component.loadData()
  tick()
  fixture.detectChanges()
  expect(component.data).toBeTruthy()
}))
```

</example>

## Strict Null Safety

Never use `!` non-null assertions. Use optional chaining or conditional narrowing.

<example>

```typescript
const control = component.form.get('email')
expect(control?.valid).toBeTrue()
expect(control?.hasError('required')).toBeTrue()
```

</example>

<example type="invalid">

```typescript
expect(component.form.get('email')!.valid).toBeTrue()  // ❌
```

</example>
