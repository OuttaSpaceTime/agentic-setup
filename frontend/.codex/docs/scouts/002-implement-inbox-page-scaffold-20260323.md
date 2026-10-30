# Scout Draft: Implement Inbox Page Scaffold

Status: scoped for first-pass implementation planning

## 1. Source Request

Ticket text provided by the user:

> Implement the Inbox Page Scaffold
>
> The inbox page contains membership specific notifications very similar to the emails that are sent out to the user right now.
>
> This Inbox will replace most e-mails eventually. This ticket will provide the basic page UI.

Acceptance criteria captured from the request:

- `/inbox` route
- visible only on staging and development for now
- no global loading spinner for initial inbox state
- no `/inbox/:id` route
- browser back button via `#` fragments may be supported
- mobile opens item details in a modal
- desktop shows details in the right pane and selects the first item by default
- toggle buttons: `All` and `Unread`
- refresh button checks for new items, prepends missing items, shows spinner during refresh, and toasts on error
- detail pane has `Mark as unread` and `Mark as read`
- card list needs selected/read/title/timestamp inputs
- infinite scroll pagination spinner at the bottom

Implementation note from the user:

- first implementation will use a mock service
- the mock service is only for the initial page load
- everything else will be mock components with projected content and route logic
- route blocking will use `canMatch`

## 2. Fast Context Map

Likely affected areas:

- app routing in `src/app/app.routes.ts`
- notifications feature routing in `src/app/features/notifications/notifications.routes.ts`
- sidebar navigation in `src/app/core/layout/components/sidebar/sidebar.component.ts` and `.html`
- global layout selection in `src/app/app.component.ts` and `.html`
- inbox/list/detail scaffolds likely near existing notifications components
- shared list and layout primitives in `src/app/shared/components/generic-list/*`
- detail/pane layout helpers in `src/app/core/components/detail-layout/*` and `pane-layout/*`
- toast and request-state handling in shared/core services

Search terms that matter:

- `notifications`
- `SidebarTwoColumnLayout`
- `devModeOnly`
- `isStaging`
- `fragment`
- `withRequestState`
- `GenericListComponent`

## 3. Current Code Path Snapshot

### App route entry

- `src/app/app.routes.ts` lazy-loads `notifications` at `/notifications`.
- No `inbox` route exists yet.

### Existing notifications feature

- `src/app/features/notifications/notifications.routes.ts` uses a list route at `''` and a detail route at `:id`.
- The list route requires login, membership, notification permission, and appends the default sort query parameter.
- The detail route also requires `read:notifications` and renders the notification detail page with child tabs.

### Existing list/detail behavior

- `src/app/features/notifications/pages/index/notifications.component.ts` renders `PaneLayoutComponent` plus `GenericListComponent` and `NotificationCardComponent`.
- `src/app/features/notifications/pages/detail/notification.component.ts` fetches a single notification by pushed id and renders a `DetailLayoutComponent` after the request resolves.
- `src/app/shared/components/generic-list/generic-list.component.html` shows a centered spinner only when the list has no data yet, and a load-more spinner at the bottom once items exist.

### Existing visibility gates

- `src/app/core/services/development.service.ts` exposes `isDevMode()` and `isStaging()`.
- `src/app/core/layout/components/sidebar/sidebar.component.ts` supports `devModeOnly` menu entries, but the current menu entries do not use a staging-only flag.

## 4. Checkpoint 1/6: Problem Frame

What success seems to mean:

- introduce a new inbox surface without disturbing the current notifications feature
- keep initial inbox data ready before the page paints, rather than flashing a generic loading spinner
- make the page responsive: modal detail on mobile, split-pane detail on desktop
- scope the feature to staging/development visibility only

First missing information that can still change planning direction:

- whether visibility restriction must be enforced at the router level, menu level, or both
- whether the inbox needs existing permission checks or different permissions from notifications
- how much of the responsive behavior is coordinated by the shell versus the mock components
- whether the route should support hash fragments from day one or just avoid breaking them

## 5. Evidence Notes

### Evidence block: requirement

- location: user-provided ticket text
- evidence path: ticket intro -> acceptance criteria -> UI/routing/responsiveness sections
- excerpt:
  - `/inbox`
  - "This page should only be visible on staging and development for now"
  - "We want to avoid global loading spinners for this page"
  - "There's no `/inbox/:id` route"
- interpretation: the new page is not a direct reuse of the current `notifications/:id` detail route; the initial experience and visibility rules are explicitly different.
- unknowns: data source, route guard strategy, and whether the new page reuses the current notification model.

### Evidence block: module map

- location: `src/app/app.routes.ts:47` -> `src/app/features/notifications/notifications.routes.ts:14` -> `src/app/features/notifications/pages/index/notifications.component.ts:15`
- excerpt:
  - `path: 'notifications'`
  - `path: ''`
  - `path: ':id'`
  - `component: NotificationsComponent`
  - `component: DetailNotificationComponent`
- interpretation: the current notifications feature is list/detail routed, so the inbox will likely be a new route tree rather than a small mutation of the existing one.
- unknowns: whether inbox should live under `features/notifications` or a new `features/inbox` area.

### Evidence block: contract

- location: `src/app/features/notifications/services/notifications.service.ts:21` -> `src/app/core/json-api-crud-service.service.ts:42`
- excerpt:
  - `public notification$ = this.id$.pipe(switchMap((id) => this.show(id)), shareReplay())`
  - `index(params, context = null as HttpContext)`
  - `show(id: string, context = null as HttpContext)`
- interpretation: the current service is centered on fetching a single selected notification and generic list pages, not on inbox-specific initial navigation state.
- unknowns: whether the inbox needs separate collection refresh semantics and read/unread mutation methods.

## 6. Open Questions for the Next Checkpoint

1. Is `/inbox` a new feature module and route tree, or should it be implemented inside the existing notifications module with different entry points?
2. Should staging/dev-only visibility be enforced only in the sidebar, or should direct navigation to `/inbox` also be blocked in routing?
3. What should the mock service return on initial load: a full inbox collection with the first selected item, or just the page-level shell state plus an item list?
4. Should hash fragments be preserved by the route and selection logic now, or only reserved for a future implementation?

## 7. Current Blocker

The ticket was initially not specific enough to plan implementation safely. The user has now narrowed the first pass to shell, bare routing, resolver, and mock initial load, which is enough to proceed with a minimal plan.

Recommended clarification request:

- Is `/inbox` a new standalone feature module, or should it live under the existing notifications feature?
- Should unsupported environments be blocked only by `canMatch`, or also hidden from navigation?
- What exact UI interactions are in scope for this first scaffold beyond initial mock loading?
- Should the first implementation preserve hash fragments and back-button behavior, or is that deferred?
- Should the desktop detail pane auto-select the first item only on first load, or also after refresh/prepend updates?

## 8. Scoped First-Pass Decision

Accepted first-pass scope:

- new inbox route and resolver
- shell-only implementation
- mock service only for the initial page load
- mock components with projected content for the rest of the page
- route blocking through `canMatch`

Deferred from first pass:

- real backend integration
- mutable read/unread interactions
- refresh, pagination, and mobile modal behavior beyond shell wiring

## 4. Decision Gates

### Gate 1: Route Blocking

- question being decided: how is `/inbox` hidden on non-dev/non-staging environments?
- selected direction: use `canMatch`
- alternatives considered: sidebar-only hiding, `canActivate`, or both
- rationale: `canMatch` prevents the route from matching at all, which is the correct boundary for a feature that should not be visible in production yet
- confidence: high
- unresolved blockers: none
- required for Now: yes

### Gate 2: Mock Scope

- question being decided: what does the mock service own in the first iteration?
- selected direction: initial page-load data only
- alternatives considered: owning selection, refresh, pagination, and read/unread state
- rationale: the user explicitly narrowed the mock service to initial load; the rest can be mocked through components and projected route content
- confidence: high
- unresolved blockers: none
- required for Now: yes

### Gate 3: Interaction Ownership

- question being decided: where do selection and page behavior live?
- selected direction: page shell and route logic
- alternatives considered: central inbox service or backend-backed state
- rationale: the scaffold can be built around routing, component composition, and projected content without coupling to a real data layer
- confidence: medium
- unresolved blockers: hash-fragment behavior and desktop reselection semantics
- required for Now: yes
