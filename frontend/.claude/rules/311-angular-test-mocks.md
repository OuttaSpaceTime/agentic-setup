---
paths:
  - "src/**/*.spec.ts"
---

# Angular Test Mocks

## Choosing a Mock Pattern

| What changes between tests | Pattern |
|---|---|
| Observable stream value | Shared `BehaviorSubject` — call `.next()` per test |
| Method return value (fixed per test) | `.and.returnValue()` in the test body |
| Method return value (derived from argument or varies by describe block) | `.and.callFake()` in `beforeEach` with a mutable closure variable |
| Plain property on a component input | Direct assignment in test body |
| Property on a `jasmine.SpyObj` service | `spyPropertyGetter(spy, 'prop').and.returnValue(...)` per test |
| Getter-backed property on the component itself | `spyOnProperty(component, 'prop').and.returnValue(...)` per test |
| `CurrentSessionService` state | `withSession` / `withoutPermissions` helpers |

## Jasmine Spy Objects

Always pass the type parameter. Use the 3-argument form when mocking observable properties.

<example>

```typescript
// Methods only
mockService = jasmine.createSpyObj<MyService>('MyService', ['create', 'delete'])

// Methods + observable properties
mockService = jasmine.createSpyObj<MyService>(
  'MyService',
  ['pushId'],
  { monitoringList$: monitoringListSubject.asObservable() }
)

// Properties only (no methods)
mockService = jasmine.createSpyObj<MyService>('MyService', [], {
  hasApiCredits$: hasApiCreditsSubject.asObservable()
})
```

</example>

## Observable Dependencies (BehaviorSubject pattern)

Declare at `describe` scope, recreate in `beforeEach`, call `.next()` in the test body before `detectChanges()`.

<example>

```typescript
let stateSubject: BehaviorSubject<MembershipLimitState>
let mockService: jasmine.SpyObj<MembershipAccessService>

beforeEach(() => {
  stateSubject = new BehaviorSubject<MembershipLimitState>({ canEdit: true, limitReached: false })
  mockService = jasmine.createSpyObj<MembershipAccessService>('MembershipAccessService', [], {
    membershipLimitState$: stateSubject.asObservable()
  })
  // ... TestBed setup
})

it('disables invite when limit is reached', () => {
  stateSubject.next({ canEdit: true, limitReached: true })
  fixture.detectChanges()
  expect(fixture.debugElement.query(By.css('[data-test-id="invite-btn"]')).nativeElement.disabled).toBeTrue()
})
```

</example>

## callFake with Closure Variable

Use when a method's return value varies by `describe` block or depends on test-local state.

<example>

```typescript
let devModeEnabled: boolean

beforeEach(() => {
  devModeEnabled = true  // default
  mockService = jasmine.createSpyObj<DevelopmentService>('DevelopmentService', ['isDevMode'])
  mockService.isDevMode.and.callFake(() => devModeEnabled)
})

describe('in production', () => {
  beforeEach(() => { devModeEnabled = false })
  it('hides dev tools', () => { /* ... */ })
})
```

</example>

## spyPropertyGetter

Use `spyPropertyGetter` from `@shared/spec/spies/utilities.module` to reconfigure a getter property on a `jasmine.SpyObj` per test. Never directly assign to a SpyObj property — it is silently ignored.

<example>

```typescript
import { spyPropertyGetter } from '@shared/spec/spies/utilities.module'

// beforeEach — set default value via createSpyObj
mockService = jasmine.createSpyObj<StatusService>('StatusService', [], {
  statusMessage: 'All systems operational'
})

// per test — override the getter
spyPropertyGetter(mockService, 'statusMessage').and.returnValue('Degraded')
fixture.detectChanges()
```

</example>

<example type="invalid">

```typescript
mockService.statusMessage = 'Degraded'  // ❌ silently ignored on SpyObj
```

</example>

For getter-backed properties on the **component itself** (not a spy), use `spyOnProperty`:
```typescript
spyOnProperty(component, 'canEditOrgSubscriptions').and.returnValue(true)
```

## Session Mocking

Always use helpers from `@shared/spec/spies/session.module` — never mock `CurrentSessionService` manually.

<example>

```typescript
import {
  provideMockCurrentSession,
  withAllPermissions,
  withoutPermissions,
  withSession,
} from '@shared/spec/spies/session.module'

// In TestBed providers:
provideMockCurrentSession()
provideMockCurrentSession({ initialSession: buildCurrentSession({ loginState: 'LoggedIn' }) })

// Mutate session within a test:
const session = TestBed.inject(CurrentSessionService)
withAllPermissions(session)
withoutPermissions(session, 'invite:org:membership:role:admin')
withSession(session, { loginState: 'LoggedOut' })
```

</example>

## provideMockService

Use `provideMockService` from `@shared/spec/provide-mock-service` to auto-mock all public methods and register in TestBed.

```typescript
import { provideMockService } from '@shared/spec/provide-mock-service'

let mockService: jasmine.SpyObj<MyService>

beforeEach(() => {
  mockService = provideMockService(MyService)
  fixture = TestBed.createComponent(MyComponent)
})
```
