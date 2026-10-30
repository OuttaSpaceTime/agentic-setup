# Review: Connect the Inbox Reminder Setting

**Branch:** `547-connect-the-inbox-reminder-setting`
**Issue:** #547 — Connect the Inbox Reminder setting
**Date:** 2026-04-13

## Change Summary

Single commit: `7bb7caea Add a new inbox reminder schedule setting UI`

23 files changed, +425 / -148 lines.

The change does three things:
1. Replaces `DevelopmentService` with an `ENVIRONMENT` injection token (`development | staging | production`)
2. Adds an `*unreleased` structural directive that hides content in production
3. Adds `InboxReminderSettingComponent` (select dropdown for `none | weekly | daily`) to the sidebar settings menu
4. Refactors `UserSettingsHttpService` → `AnnouncementSettingsService`, updates the settings UI from `ix-tile` to `ui-card`

## Gate Checks

| Check | Result |
|-------|--------|
| editorconfig-checker | PASS (errors are in pre-existing `src/readme-oss.html`, not changed files) |
| ng lint --fix | PASS |
| Dev server compilation | PASS |

## Code Areas Inspected

- `src/app/core/services/environment.token.ts` (new)
- `src/app/core/services/environment.token.spec.ts` (new)
- `src/app/shared/directives/unreleased/unreleased.directive.ts` (new)
- `src/app/shared/directives/unreleased/unreleased.directive.spec.ts` (new)
- `src/app/features/memberships/models/membership-setting.model.ts` (new)
- `src/app/features/memberships/pages/inbox-reminder-setting.component.ts` (new)
- `src/app/features/memberships/services/membership-settings-http/membership-settings-http.service.ts` (new)
- `src/app/features/memberships/services/membership-settings/membership-settings.service.ts` (new)
- `src/app/features/user-settings/services/announcement-settings/announcement-settings.service.ts` (new)
- `src/app/features/user-settings/pages/user-settings-menu.component.ts` (modified)
- `src/app/core/layout/components/sidebar/sidebar.component.ts` (modified)
- `src/app/core/layout/components/sidebar/sidebar.component.html` (modified)
- `src/app/core/type-to-model.ts` (modified)
- `src/app/shared/types/resource.type.ts` (modified)
- `src/app/features/inbox/guards/inbox-can-match.guard.ts` (modified)

## Findings

| # | Severity | File | Summary | Status |
|---|----------|------|---------|--------|
| 1 | 🛑 blocker | `inbox-reminder-setting.component.ts:60` | `updateSetting()` ignores the selected value — sends no payload | pending |
| 2 | 🛑 blocker | `membership-settings-http.service.ts:21-23` | `updateInboxReminderFrequency()` is a stub returning `of({})`, not calling the API | pending |
| 3 | 🛑 blocker | `announcement-settings.service.ts:27-29` | `show()` override returns hardcoded mock instead of calling the real API | pending |
| 4 | 🛑 blocker | `membership-settings-http.service.ts:25-27` | `show()` override returns hardcoded mock instead of calling the real API | pending |
| 5 | ⚠️ major | `membership-settings.service.ts` (entire file) | Dead service — not injected anywhere, duplicates `MembershipSettingsHttpService` | pending |
| 6 | ⚠️ major | `inbox-reminder-setting.component.ts:51-53` | `show()` called without `CUSTOM_ERROR_HANDLING` — 5xx will redirect to /500 instead of showing inline error | pending |
| 7 | ℹ️ minor | `environment.token.ts:28-29` | `ENVIRONMENT` factory uses regex `/staging/` on hostname — matches any subdomain containing "staging" | pending |

## Open Questions

- Are the stub `show()` and `updateInboxReminderFrequency()` methods intentional placeholders for this PR (i.e., backend not ready yet), or are they bugs?
- The `isStaging` getter was removed from `SidebarComponent` — was anything using it?

## Manual QA Checklist

1. **Sidebar settings (dev/staging):** Open sidebar → Settings → verify "Reminder Settings" card appears with a select dropdown showing None/Weekly/Daily
2. **Sidebar settings (production):** Open sidebar → Settings → verify "Reminder Settings" card is hidden
3. **Announcements toggle:** Settings → toggle "Receive emails" → verify the API call fires with the correct boolean
4. **Error state:** With network disconnected → open Settings → verify inline error state (disabled select / indeterminate toggle), NOT a redirect to /500
