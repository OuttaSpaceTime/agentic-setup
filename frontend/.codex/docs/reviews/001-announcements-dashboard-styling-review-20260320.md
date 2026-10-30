# Review Draft: Announcements dashboard styling review

Date: 2026-03-20
Scope: `main...HEAD`
Status: in_progress

## Validations Run

- `git --no-pager diff --stat main...HEAD`
- `git --no-pager diff main...HEAD -- src/app/features/dashboard src/app/core/type-to-model.ts src/app/shared/types/resource.type.ts`
- `git status --short`

## High-Level Change Map

| File | Type | Purpose | Key change |
| --- | --- | --- | --- |
| `src/app/features/dashboard/components/announcements/announcements.component.ts` | component class | dashboard announcement container | imports simplified back to `DashboardTileComponent` + announcement tiles only |
| `src/app/features/dashboard/components/announcements/announcements.component.html` | template | renders loading/error/empty/success states | announcements wrapped in one dashboard tile again |
| `src/app/features/dashboard/components/announcements/announcements.component.css` | stylesheet | stack layout and state tile styling | sibling tile spacing and state tile border/surface styling |
| `src/app/features/dashboard/components/announcements/announcement-tile/announcement-tile.component.ts` | component class | leaf announcement presentation | per-item `IxIcon` restored |
| `src/app/features/dashboard/components/announcements/announcement-tile/announcement-tile.component.html` | template | announcement tile markup | original icon + date + title + html content structure restored |
| `src/app/features/dashboard/components/announcements/announcement-tile/announcement-tile.component.css` | stylesheet | individual announcement tile styling | multiple iterations collapsed into `component-2` surface + soft border + original card layout |

## Current Execution Flow

1. Dashboard renders `<app-announcements />` inside the dashboard page.
2. `AnnouncementsComponent` fetches announcements through `AnnouncementsService.index({})`, maps `resources`, and wraps the stream with `withRequestState()`.
3. The template renders one outer `app-dashboard-tile` titled `Announcements`.
4. Success state renders one `app-announcement-tile` per announcement.
5. Each announcement tile renders icon, publish date, title, and trusted HTML content.

## Code Walkthrough

- symbol type: template block
- symbol name: `AnnouncementsComponent` state rendering
- location: `src/app/features/dashboard/components/announcements/announcements.component.html:1`
- code path: `src/app/features/dashboard/pages/dashboard/dashboard.component.html:19 -> src/app/features/dashboard/components/announcements/announcements.component.ts:32 -> src/app/features/dashboard/components/announcements/announcements.component.html:1`
- body excerpt:

```html
<app-dashboard-tile title="Announcements">
  @if (state$ | async; as state) {
    @if (state.loading) {
      <div class="status-tile">
        <app-centered-spinner />
      </div>
    } @else if (state.error) {
      <div class="status-tile">
        <ix-empty-state
          header="Announcements are currently unavailable"
          icon="error"
        />
      </div>
    } @else if (state.data && state.data.length > 0) {
      @for (announcement of state.data; track announcement.id) {
        <app-announcement-tile [announcement]="announcement" />
      }
    } @else {
      <!-- empty state -->
    }
  }
</app-dashboard-tile>
```

- interpretation: the changed flow is now visually minimal again: one standard dashboard tile containing vertically stacked announcement tiles, with no extra section-specific header/subtitle layer.
- review questions:
  - do the nested announcement tiles still align with Ix elevation guidance after the latest color and border changes?
  - is the current styling minimal, or are there leftover iterations from the earlier design exploration that no longer serve a purpose?

## Early Review Questions

- Should the inner announcement tiles inherit the original `component-3` styling, or is `component-2 + soft-bdr` the more locally consistent nested pattern inside `DashboardTileComponent`?
- Is the per-item icon still desired now that announcements are grouped under a shared `Announcements` dashboard tile heading?

## Findings

### No material findings

I did not find a correctness bug, acceptance-criteria regression, or architectural violation in the current `main...HEAD` diff. The branch has converged back to a codebase-aligned shape:

- one standard `DashboardTileComponent`
- one local `AnnouncementsComponent` owning fetch/request state
- one leaf `AnnouncementTileComponent` rendering the individual entries

That is minimal and consistent with nearby dashboard patterns.

### Cleanup Notes

#### 1. Unused / misleading CSS custom-property assignment

- Severity: low
- Location: `src/app/features/dashboard/components/announcements/announcement-tile/announcement-tile.component.css:26`
- Evidence:

```css
.content {
  --theme-color-primary: --theme-color-soft-text;

  grid-area: content;
  line-height: var(--theme-line-height-md);
}
```

- Why it matters: this looks like leftover styling experimentation. The value is a raw token name rather than `var(--theme-color-soft-text)`, and the current link styling no longer depends on `--theme-color-primary` anyway. It does not appear to break behavior, but it is not minimal and may mislead the next editor into thinking this declaration is still meaningful.
- Recommended action: remove the custom-property line unless a descendant actually needs it.

#### 2. Host-level flex gap is now redundant

- Severity: low
- Location: `src/app/features/dashboard/components/announcements/announcements.component.css:1`
- Evidence:

```css
:host {
  display: flex;
  flex-direction: column;
  gap: var(--theme-space-3);
}
```

- Why it matters: after the latest simplification, the host renders a single `app-dashboard-tile`, so the host-level column gap no longer affects layout. The real spacing behavior now comes from `app-announcement-tile + app-announcement-tile`.
- Recommended action: simplify `:host` to `display: block;` unless another sibling-level layout concern is intended.

## Verdict

- Correctness: aligned
- Architecture fit: aligned
- UI pattern fit: aligned
- Complexity: minimal with two minor cleanup leftovers
