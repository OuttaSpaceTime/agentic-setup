---
name: delegated_type with STI itemables — register the parent only
description: When an Inbox::Item itemable is an STI hierarchy, register only the concrete STI parent in `delegated_type(types: [...])` — never the subclasses
type: feedback
originSessionId: 482b009f-1581-4144-9941-37e27830fa90
---
When an `itemable` for `Inbox::Item#delegated_type` is itself an STI hierarchy (e.g. `MonitoringList::DependenciesChangedItem` with `::CreatedItem` / `::RemovedItem` subclasses, or `ComponentRequest::ChangedItem` with `::ProcessedItem` / `::UpdatedItem`), only the STI parent goes in the `types: [...]` list. Subclasses must NOT be added.

**Why:** Rails stores `base_class.name` in `itemable_type` for STI rows — the actual subclass is recorded in the items table's own `type` column, not in `itemable_type`. Registering subclasses in `delegated_type` would never match a real row and would surprise the validator. The existing `ComponentRequest::ChangedItem` registration in `app/models/inbox/item.rb` is the canonical example. Confirmed by Felix on the dependencies-changed STI refactor (2026-05-08).

**How to apply:**
- Adding a new itemable that uses STI: register the STI parent in `Inbox::Item#delegated_type`, no subclasses.
- Tests can still assert against the specific STI subclass using `assert_subscriber_inbox_items_created(..., type: ::CreatedItem)` — the helper in `test/application_integration_test_case.rb` detects STI descendants and additionally filters `itemable_id` against the subclass's default scope. Pass the subclass when you want subclass-level specificity, or the parent when you don't care.
- Reviewing migrations that flatten parallel tables into one STI table: expect the `delegated_type` list to shrink by one entry per pair, not stay the same.
