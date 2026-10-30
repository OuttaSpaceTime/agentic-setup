---
name: feedback-delivery-job-one-transaction
description: "For inbox/notification delivery jobs in vilocify-portal, keep one outer transaction even at high write volume — resumability/error-proofness outweighs transaction-size concerns"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8bebd381-a0ec-4fdc-ae05-afc3923fb1cc
---

For delivery jobs like `NotificationRevisionItemsDeliverAllJob`, the entire job stays wrapped in a single `Notification.transaction` (and `Current.without_organization_and_membership_scopes`). Do not propose splitting into per-ML or per-batch transactions to reduce lock duration or transaction bloat.

**Why:** if any subscription's writes fail mid-job, the whole job needs to roll back so the next cron tick reprocesses the same pending set cleanly. Partial-commit designs require explicit checkpointing and resumption logic, which is not worth the complexity for this workload.

**How to apply:** when optimizing delivery jobs, look for wins that work *inside* the one transaction — batched `insert_all`, eliminating N+1s, precomputing matching MLs/events, query plan improvements. Don't suggest per-batch commits, per-org sharding into separate jobs, or anything that breaks the single-transaction guarantee.

**Exception (2026-06-09, EOL feature):** `MonitoringList::ComponentEolEventsDeliveryJob` (event-driven, fans across many orgs) was split into a parent that enqueues one **per-org** child job (`ComponentEolEventDeliveryJob`), each its own transaction. Niklas asked, Karim (owner) approved: "follow a clean approach wherever we can for scaling." Resumability comes from ActiveJob per-org retry (a failed org-job retries independently) — no watermark needed because it's not cron-driven. The single-transaction rule still holds for cron `*DeliverAllJob`s below.

**Exception (2026-05-21):** The notification revision pipeline was split into two jobs to keep total write volume tractable. Phase 1 (`NotificationRevisionEventsCreateAllJob`) is one outer txn — rule applies. Phase 2 (`NotificationRevisionItemsDeliverAllJob`) intentionally uses **per-event transactions**, each commit-or-rollback independent. The `processed_at` watermark on `MonitoringList::NotificationRevisionEvent` provides resumability (failed events stay `processed_at: nil` and are retried next run). Felix's rationale: smaller per-txn write volume, narrower lock footprint, less blocking, independent failure recovery — worth a slightly worse total runtime. Apply the one-transaction rule everywhere else (subscription mailers, single-event ML delivery jobs).
