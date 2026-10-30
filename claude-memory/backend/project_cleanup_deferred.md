---
name: project-cleanup-deferred
description: Inbox cleanup patterns, now on main (Inbox::Event::Cleanup concern, event_id columns): event_id rename, Inbox::Event registry, dependent destroy chains, global vs org-scoped events
metadata: 
  node_type: memory
  type: project
  originSessionId: f04c2fa2-9d4f-4699-94c0-72fa43a0838d
---

The inbox cleanup infrastructure matured from the `test` branch into branch `1078-deleting-a-membership-should-not-be-blocked-by-an-inbox-item-2` (commits "Implement cleanup" + "Dry up tests"), rebased onto main on 2026-06-11 after the EOL feature merged.

**Established patterns (the canonical reference for any new inbox item/event pair):**

- Every itemable: `belongs_to(:event, class_name: '...', inverse_of: :items)`; column is `event_id` (migration `20260610000000_rename_event_foreign_keys_to_event_id.rb`, all FKs `on_delete: :cascade`, `null: false`)
- Every event: `has_many(:items, ..., inverse_of: :event, dependent: :destroy)` + `include(Inbox::Event::Cleanup)` (orphan sweep: item-less events older than 2× `Inbox::Item::READ_RETENTION_DAYS`)
- `Inbox::Event.events` registry must list every event class — a test cross-checks it against `Inbox::Item.itemable_types` via `reflect_on_association(:event)`
- `Inbox::Item` `delegated_type(:itemable, dependent: :destroy, ...)` — inbox item destroy kills the itemable
- Org-scoped events: `Organization::Inbox` concern `has_many ... dependent: :destroy`. Global events (ComponentEol, SupportDropped) are NOT in it — they survive org destroy and get swept as orphans later
- Controller preloads uniformly via `.preload(itemable: :event)`
- recurring.yml: `Inbox::Item.cleanup_due` 03:15, `Inbox::Event.cleanup_due` 03:30, `MonitoringList::NotificationRevision.cleanup_due` 03:45 (all envs incl. production)

**How to apply:** When a new inbox item/event pair lands on main, align it to these patterns on this branch (EOL pair was aligned 2026-06-11: rename folded into the existing 20260610000000 migration, registry + cleanup tests extended).
