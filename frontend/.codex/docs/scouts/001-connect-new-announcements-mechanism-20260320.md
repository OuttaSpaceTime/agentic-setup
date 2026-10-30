# Scout Draft: Connect the new announcements mechanism

Date: 2026-03-20
Status: Draft
Readiness: not ready

## Source Request

### Intro

There's a new internal /api/v2/announcements endpoint. We're going to remove our existing announcement mechanism and replace it with the new mechanism where we pull announcements from the internal api endpoint.

### Acceptance criteria

- Get rid of the old announcement mechanism
- Use the announcements that are returned by `/api/v2/announcements` instead
- The UI should always show the latest published announcement fully (similar to the current UI)
- Always show all 3 announcements.
- The API returns content as HTML. We're the author of these announcements and can trust it. Make sure it renders nicely and correctly formatted.
- Visiting the dashboard reloads the announcements.

### Notes

- Use the new JSON:API client instead and introduce a regular FE model for it.
- Endpoint: `GET /api/v2/announcements`
- Auth: cookie auth, `sessionToken`
- Response media type: `application/vnd.api+json`
- Response resources: type `"announcements"` with attributes `title`, `html`, `publishOn`, `createdAt`, `updatedAt`
- Backend guarantees verified in notes: ordered by `publish_on DESC, created_at DESC`, limited to 3, future and deleted announcements excluded

## Fast Context Map

- Primary UI entrypoint: dashboard page and standalone announcements component
- Legacy data source: bundled JSON fixture under dashboard models
- Integration seam for new endpoint: shared `JsonApiClientService` + `AttributesMap` + `typeToResource`
- Rendering seam for trusted HTML: existing `safeHtml` pipe already used by the announcement tile
- Reload seam for dashboard visits: dashboard route guards currently force-refresh session only

## Current Execution Walkthrough

1. Visiting the dashboard activates the route and calls `CurrentSessionService.forceRefresh()` during `canActivate`.
2. The dashboard page template always renders `<app-announcements />`.
3. `AnnouncementsComponent.ngOnInit()` loads a static JSON file and filters it client-side by `displayUntil`.
4. The component template renders all active announcements or an empty state if none remain.
5. Each tile renders title, `createdOn`, and HTML content through `[innerHTML]` plus `safeHtml`.

## Walkthrough Evidence

### Evidence 1

- evidence type: requirement
- location: user request
- evidence path: ticket text
- short excerpt: "Use the announcements that are returned by `/api/v2/announcements` instead" and "Visiting the dashboard reloads the announcements."
- interpretation: the feature is not just a data-shape swap; it changes the source of truth and adds a navigation-triggered refresh expectation.
- unknowns: whether "reloads" means route activation only or also same-route revisits without full component destruction.

### Evidence 2

- evidence type: behavior trace
- location: `src/app/features/dashboard/dashboard.routes.ts:8`
- evidence path: `src/app/features/dashboard/dashboard.routes.ts:8 -> src/app/features/dashboard/pages/dashboard/dashboard.component.html:1 -> src/app/features/dashboard/components/announcements/announcements.component.ts:14`
- short excerpt:
  - route `canActivate: [..., () => inject(CurrentSessionService).forceRefresh()]`
  - dashboard template renders `<app-announcements />`
  - `ngOnInit() { this.announcements = Announcement.activeAnnouncements(announcementsData) }`
- interpretation: dashboard visits already execute one route-time refresh action, but announcement data itself is not fetched from the server and is only computed from a bundled asset during component init.
- unknowns: whether the router reuses this component in any navigation pattern that would skip `ngOnInit`, and whether the new feature should piggyback on route activation or own its refresh trigger.

### Evidence 3

- evidence type: module map
- location: `src/app/features/dashboard/models/announcement/announcement.model.ts:3`
- evidence path: `src/app/features/dashboard/models/announcement/announcement.model.ts:3 -> src/app/features/dashboard/models/announcement/announcements-data.json`
- short excerpt:
  - `RawAnnouncement { title; content; createdOn; displayUntil }`
  - `isActive()` compares `displayUntil` against today
- interpretation: the current FE model encodes old business rules that the backend now owns: active-window filtering and legacy `content`/`displayUntil` fields.
- unknowns: whether any UI code outside dashboard depends on `displayUntil` semantics or the old `RawAnnouncement` type.

### Evidence 4

- evidence type: contract
- location: `src/main.ts:53`
- evidence path: `src/main.ts:53 -> src/app/core/interceptors/default-headers.interceptor.ts:3`
- short excerpt:
  - `provideHttpClient(withInterceptors([... defaultHeadersInterceptor ...]))`
  - interceptor sets `withCredentials: true`, `Accept: application/vnd.api+json`, `Content-Type: application/vnd.api+json`
- interpretation: transport requirements from the backend notes align with the app's default HTTP behavior, so the announcement service should fit the shared client stack without custom fetch code.
- unknowns: none at transport level; response typing and model registration are still open.

### Evidence 5

- evidence type: contract
- location: `src/app/shared/types/resource.type.ts:49`
- evidence path: `src/app/shared/types/resource.type.ts:49 -> src/app/core/type-to-model.ts:24`
- short excerpt:
  - `AttributesMap` defines all JSON:API resource types
  - `typeToResource` maps each type to a model constructor
- interpretation: introducing a regular FE model for announcements likely requires central registration, not just a local dashboard model class.
- unknowns: whether any newer JSON:API abstraction exists in this branch beyond `JsonApiClientService`; current inspection only found this stack.

### Evidence 6

- evidence type: behavior trace
- location: `src/app/features/dashboard/components/announcements/announcement-tile/announcement-tile.component.html:16`
- evidence path: `src/app/features/dashboard/components/announcements/announcement-tile/announcement-tile.component.html:16 -> src/app/shared/pipes/safe-html.pipe.ts:8`
- short excerpt:
  - `[innerHTML]="announcement.content | safeHtml"`
  - `bypassSecurityTrustHtml(html)`
- interpretation: there is already an established trusted-HTML rendering path for announcement content. The new API field is `html`, so the likely UI delta is model-field mapping plus any CSS cleanup needed for richer markup.
- unknowns: current tile CSS uses `white-space: pre-wrap`; that may interact poorly with backend-generated block HTML like lists or paragraphs.

## Known Facts

- The old mechanism is file-backed and dashboard-local.
- The current UI can already render trusted HTML.
- The app already sends JSON:API headers and cookies on HTTP requests.
- The dashboard route already performs one refresh action on navigation.
- The acceptance criteria explicitly say to keep showing 3 announcements, not just a latest single item.

## Plausible Hypotheses

- The intended implementation is a new `announcements` model + HTTP service based on `JsonApiClientService`, consumed by `AnnouncementsComponent`.
- The old `Announcement` model likely needs replacement rather than extension, because its fields and business rules no longer match the backend contract.
- The empty state may become effectively unreachable in production if backend always returns up to 3 published announcements, but tests should still cover the zero-results case.

## Unresolved Unknowns

- Whether the "new JSON:API client" note refers to the existing `JsonApiClientService` or to another newer helper not discoverable from the current search results.
- Whether "Visiting the dashboard reloads the announcements" needs a route-resolver/guard-driven fetch or simply a component fetch on each dashboard instantiation.
- Whether the current tile styling renders backend-authored rich HTML cleanly enough for lists, paragraphs, and links without additional CSS.

## Early Affected Areas

- `src/app/features/dashboard/components/announcements/*`
  - current responsibility: dashboard announcement fetch/render shell
  - impact: source-of-truth change from local JSON to API data
- `src/app/features/dashboard/models/announcement/*`
  - current responsibility: legacy model and active-window filtering
  - impact: likely replacement with new FE model matching JSON:API resource attributes
- `src/app/shared/types/resource.type.ts`
  - current responsibility: central JSON:API resource typing
  - impact: probable addition of `"announcements"` resource type
- `src/app/core/type-to-model.ts`
  - current responsibility: convert JSON:API resources to FE models
  - impact: probable registration of announcement resource mapper
- new dashboard announcement HTTP service file
  - current responsibility: none yet
  - impact: fetch `/api/v2/announcements` via shared JSON:API client

## Early Test Surface

- `src/app/features/dashboard/components/announcements/announcements.component.spec.ts`
  - current responsibility: local rendering and empty state
  - impact: should shift from static active-filter tests to API-fed rendering/reload behavior
- `src/app/features/dashboard/components/announcements/announcement-tile/announcement-tile.component.spec.ts`
  - current responsibility: title/date/html rendering
  - impact: likely date-field semantics and richer HTML assertions
- possible new service spec
  - impact: verify resource path, resource type, and mapping through the shared JSON:API stack
- `src/app/features/dashboard/dashboard.routes.spec.ts`
  - current responsibility: session refresh on dashboard visit
  - impact: may need adjacency review if announcement reload is tied to route activation

## Decision Gates Preview

- Gate: keep fetch orchestration in the component or move it into route-time loading
  - why it matters: determines how "reload on visit" is guaranteed
- Gate: keep or remove the empty-state branch
  - why it matters: acceptance criteria emphasize three announcements, but zero-result resilience still affects UX and tests
- Gate: whether tile CSS needs adjustment for authored HTML blocks
  - why it matters: acceptance criteria call out correct formatting, not just HTML insertion

## Current Scout Verdict

- Scope confidence: medium
- Planning readiness: conditional
- Blocking unknowns:
  - confirmation that `JsonApiClientService` is the intended "new JSON:API client"
- Non-blocking but important:
  - verify same-route revisit semantics if "reload on visit" is interpreted strictly
  - inspect HTML formatting expectations against current CSS before implementation

## Checkpoint Updates

### 2026-03-20: User clarification

- Decision captured: display `publishOn` in the tile, not legacy `createdOn`
- Impact:
  - current tile markup and tests that read `createdOn` must change
  - new FE model should expose `publishOn` as the dashboard display date
- Decision captured: use `JsonApiClientService` as the JSON:API client for this ticket
- Decision captured: the `AnnouncementsComponent` owns fetching and reloading behavior
- Decision captured: route reload behavior should be satisfied by the component reloading appropriately on dashboard visits
- Decision captured: announcement HTML styling must stay coherent with existing Ix usage; no existing Ix component is a direct fit, so custom styling around trusted HTML is expected
- Decision captured: backend error should render a non-critical error state on the dashboard using an empty-state-like pattern
- Decision captured: zero returned announcements should render the normal empty state using the existing consistent empty-state pattern
- Decision captured: use the hybrid styling direction
  - keep Ix-based title/date shell
  - render trusted backend HTML in a custom rich-text region
  - style supported tags with theme-token spacing and Ix-coherent typography rhythm
  - stop relying on plain-text-oriented `white-space: pre-wrap` as the main formatting strategy
- Supported rendered HTML from backend markdown:
  - `h1`
  - `p`
  - `strong`
  - `em`
  - `u`
  - `a`
  - `ul`
  - `ol`
  - `li`
