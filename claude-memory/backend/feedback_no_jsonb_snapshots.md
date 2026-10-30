---
name: No jsonb snapshots — use live links with fallbacks
description: For inbox-item / event modeling, never store role/priorities/etc. as jsonb snapshots — use live FK associations and fall back to "(deleted)" / "(subscription removed)" when the linked record is gone
type: feedback
originSessionId: c4e79db3-ddba-4a07-9d96-496e2682800a
---
Do not introduce jsonb snapshot columns (e.g. `roles_snapshot`, `priorities_snapshot`) on event/item records to capture the state of related data at event-creation time. Use live FK associations to the source record and render fallbacks when the link resolves to nil.

**Why:** This matches the existing project rule that membership references must never be snapshotted (FK only, render "(deleted)" when membership is gone). Felix wants the same discipline applied to *all* related-record state (subscription role, priorities, etc.), not just memberships. Snapshots drift from live data and bloat the schema; rendering "(subscription removed)" is acceptable when the live record is gone.

**How to apply:** When designing event/item models that need to surface related-record state (role, priorities, etc.), give the item a `belongs_to :subscription` (or whatever the live source is), read attributes from it at render time, and fall back gracefully when the association is nil. Same applies to delivery jobs — look up live subscriptions at job execution time and skip recipients whose subscription is gone. The only acceptable "snapshot"-style column on these records is something like `ml_name_snapshot` for the monitoring list NAME (since that's already established in the project) — but not full state blobs.
