---
name: Current work — ML↔CR linking and org-wide visibility
description: Active feature work on MonitoringList-ComponentRequest linking and org_wide_visible POC as of 2026-04-08
type: project
---

**MonitoringList ↔ ComponentRequest linking (2026-04-08):**
Three issues in flight: #974 (join table, merged), #980 (PATCH relationship endpoint, open branch), #1016 (org_wide_visible POC, open branch). Felix scouted all three and provided MR feedback on #980 and #1016.

**Why:** SDK creates ComponentRequests for unmatched components. When matched, components should auto-add to linked MonitoringLists. Currently requires re-running the SDK after matching. Part of Siemens CI/CD single-tenant integration.

**Key findings from scout (2026-04-08):**
- #980 PATCH endpoint has bugs: missing organization_id on insert_all!, no transaction/lock/validation. Diverges from established `replace_components!` pattern.
- #1016 visible scope has AND-vs-OR bug: `org_wide_visible.subscribed_by_with_descendants(...)` restricts instead of expanding visibility. Needs `.or()`.
- #1016 changes the ML authorization model globally — `.visible` scope is the gatekeeper for all relationship controllers, copies, and exports.
- The matching callback (auto-add component to MLs on CR match) has no ticket and no code yet — it's the most complex piece.
- Felix challenged why #1016 is in the same milestone as CR↔ML linking — they're technically independent.

**How to apply:** Scout report at `.claude/docs/scouts/001-ml-component-request-org-visibility-20260408.md`. Felix is in a review/challenge posture on these MRs, not implementing.
