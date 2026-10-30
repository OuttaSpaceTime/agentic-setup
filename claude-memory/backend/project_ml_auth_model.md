---
name: MonitoringList authorization model implications
description: Non-obvious fact that MonitoringList.visible scope is the sole gatekeeper for all read paths including relationships, copies, and exports
type: project
---

`MonitoringList.visible` is the single authorization gatekeeper for ALL read-path controllers: index, show, relationship reads (components, subscriptions, children, parents), copies (`monitoring_list_copies_controller.rb`), and exports (`export/excel_manager.rb`).

**Why:** Any change to `.visible` (like adding `org_wide_visible`) automatically expands access to all these paths — not just the ML itself. This was surfaced during the 2026-04-08 scout of #1016. The `editable` scope (write path) is separate and unaffected.

**How to apply:** When reviewing or implementing changes to MonitoringList visibility, always trace the blast radius through relationship controllers and the copy/export paths. The established pattern for write actions uses `authorize!(MonitoringList.visible, write_scope: :where_X_editable)` — the ML is found via `.visible` but mutations are gated by a separate write scope. Changes to `.visible` affect the find step for both read AND write controllers.
