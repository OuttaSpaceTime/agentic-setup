---
name: sectel-inbox-dual-pipeline
description: Why the SecurityTelegram email pipeline and the notification-revision inbox pipeline run in parallel with separate watermarks
metadata: 
  node_type: memory
  type: project
  originSessionId: 349daac5-d32e-4dbc-bf5d-1f911fb98f8e
---

On branch work (May 2026), the notification-delivery system intentionally runs **two parallel pipelines** for new security content:

- **Legacy email** — `SecurityTelegram` model + `security_telegrams_{prepare,send,purge}_all_job` + `lib/tasks/sectels.rake` + the `security_telegram.html.erb` digest. Restored from `main` after an earlier branch commit (`a7e6b0c20`) had dropped it. Owns the `notifications.last_emailed_version` watermark.
- **New inbox items** — `NotificationRevisionEventsCreateAllJob` → per-event `NotificationRevisionEventDeliverJob` → `MonitoringList::NotificationRevisionItem` inbox items. Owns `notifications.last_processed_version` (+ `processing_since`).

**Why:** the team is migrating notifications from email to in-app inbox items but keeps the old mailer running **until it can be safely dropped**. The two pipelines must not share a watermark or one starves the other — hence the separate `last_emailed_version` (sectel) vs `last_processed_version` (inbox) columns. `mailed_at` on NRIs is now unused (mailing left the inbox pipeline) — flagged as future cleanup, not dropped.

**How to apply:** do not "deduplicate" these pipelines or merge the watermarks — the parallelism is deliberate and transitional. When the mailers are finally dropped, remove the `security_telegrams_*` jobs/model/rake/recurring entries + the `last_emailed_version` column, not the inbox pipeline.

Related: "component end of life reached" is now its own **global, inbox-only** event/item (`MonitoringList::ComponentEndOfLifeReached{Event,Item}`), triggered from `ComponentPullJob#update_component!` on `eol_reached` false→true. It deliberately omits `MonitoringList::EventBase` (no org/actor/single-ML). The legacy digest email still shows EOL via `SecurityTelegram.ml_summary_hashes` + `ml.get_eol_components`. See [[no-jsonb-snapshots]], [[delivery-job-one-transaction]].
