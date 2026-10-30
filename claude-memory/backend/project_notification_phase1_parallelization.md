---
name: project-notification-phase1-parallelization
description: "Why/how NotificationEventsCreateAllJob Phase 1 can be parallelized, and the one hard prerequisite"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1de64bf4-c19f-487c-a7c1-f1162084d009
---

Investigation (2026-05-28, `test` branch) into splitting `NotificationEventsCreateAllJob` Phase 1 into parallel jobs while keeping watermark guarantees.

**Core finding:** the single big `Notification.transaction` is buying TWO things — (1) atomic writes, and (2) a *consistent point-in-time read of a volatile graph* (`fetch_ml_notification_tuples`: ML ↔ component ↔ notification, where components can be removed between pull and processing). Splitting is safe for (1); for (2) you must pin the resolution at snapshot time rather than re-derive it later.

**No-loss survives the split for free:** the per-notification watermark (`notifications.last_inbox_processed_version`) advances at the end of each notification's own Stage 1 transaction; on rollback it un-advances → `with_unprocessed_inbox_versions` re-selects → recoverable, never lost.

**The key reframe (this is the load-bearing lesson):** the "when do I trigger the next phase safely?" barrier was a symptom of welding TWO guarantees together — **correctness** (no item ever lost, non-negotiable) and **consolidation** (one inbox item shows ALL notifications for an ML, nice-to-have). Demote consolidation to best-effort (stragglers that arrive after an event was made simply form a NEW event) and the barrier *evaporates*. There is then NO barrier anywhere — every stage becomes an idempotent "process what's pending right now" sweep over durable state, mirroring the existing `NotificationEventsSweepJob` pattern.

**Barrier-free three-stage design:**
- Stage 1 (parallel, per-notification, fast): insert revision (idempotent) + resolve affected MLs *now* + write revision→ML link rows + advance watermark. Trigger/recovery: notifications with unprocessed inbox versions.
- Stage 2 (sweep): find revision→ML links with no event yet, group by ML, create one event per ML (link rows once consolidated are no longer "pending", so never re-grabbed). Trigger/recovery: pending revision→ML links. ALWAYS make a new event for currently-pending links — never wait for batch completeness.
- Stage 3 (Phase 2, unchanged): events where `processed_at IS NULL` → inbox items. Already idempotent (`monitoring_list_notification_items` unique on `(event_id, membership_id)`) and sweep-backed.

Timing Stage 2 to run *after* the notification pull job is a **consolidation-quality optimization, NOT a correctness requirement** — worst case if mistimed is more events → more inbox items, never a lost item.

**Prerequisite for safety:** revisions need a PG **exclusion** constraint on `(notification_id =, version_range &&)` (int4range overlap, not exact) so Stage 1 — which commits before the watermark gate — is idempotent on retry. Today `monitoring_list_notification_revisions` has only a non-unique `notification_id` index + a version_range check. See [[feedback-no-jsonb-snapshots]] (intent rows are FK links, not jsonb blobs).

Phase 2 verified to have no cross-event dedup (keys only on `event.id`), so event-splitting is safe-but-noisy, not lossy.

**Trigger model (finalized 2026-05-29):** snapshot as early as possible — `NotificationPullJob` (already per-notification, `with_lock` + txn, writes histories) enqueues a per-notification Stage 1 snapshot job ON COMMIT, only when a new published_or_resent history landed above the watermark (`with_unprocessed_inbox_versions`, defined notification.rb:159). `ApplicationJob` sets `enqueue_after_transaction_commit = true` (application_job.rb:2) → enqueue is dropped if the pull rolls back (achieves "rollback with txn" via deferral, NOT an in-txn row). Residual dual-write hole (commit then crash before enqueue) is closed by keeping a **Stage 1 sweep** (the shrunken role of CreateAllJob) that re-selects `with_unprocessed_inbox_versions` — no-loss is guaranteed by sweep+watermark, never by the enqueue. Mirrors existing Phase 2 inline-enqueue + hourly `NotificationEventsSweepJob`.

**Idempotency mechanism decision:** snapshot job uses `notification.with_lock` (serializes concurrent snapshots → contiguous non-overlapping version_ranges) + a UNIQUE index on `(notification_id, version_range)` enabling `insert_all(on_conflict: :nothing)` for retry-idempotency. Chose unique-index over the GiST exclusion constraint because PG `ON CONFLICT` does NOT support exclusion constraints, and the per-notification lock already prevents overlaps. (int4range supports btree → unique index works.) Revisited from earlier exclusion-constraint plan.

**Perf context (2026-05-29):** `bin/seed_database` = all defaults (2 orgs, 4000 notifs → ~2000 pending, 1000 ML/org, components_per_ml 300–1800). The OLD monolithic create-all measured ~30s on this (benchmark script `tmp/benchmark_notification_revision_pipeline.rb` is STALE — uses pre-rename class names, won't run on HEAD). DB default `statement_timeout: 11s` (database.yml); create-all bumps to 120s because monolith. Per-notification snapshots run well under 11s. Production target: ~100 orgs, start 100–200 pending notifs, scale up once stable. Goal: parallel snapshot fast at scale.

**IMPLEMENTED (2026-05-29, branch `test`, all 41 pipeline tests green).** Final job topology:
- `NotificationSnapshotJob(notification)` — Stage 1 unit: `with_lock` → create revision (unique index backstops idempotency) + resolve MLs live + write `monitoring_list_notification_revision_lists` rows (pinned ml_name_snapshot) + advance watermark.
- `NotificationPullJob` — enqueues `NotificationSnapshotJob` inside its txn, only when a published/resent history is unprocessed; `enqueue_after_transaction_commit=true` drops it on rollback (verified by test).
- `NotificationSnapshotSweepJob` — Stage 1 backstop: `with_unprocessed_inbox_versions` → enqueue snapshots.
- `NotificationEventsCreateAllJob` — REPURPOSED to Stage 2 consolidation: `DELETE ... RETURNING` claims pending links atomically (race-safe, PK-free, late inserts survive), groups by ML → one event each + event↔revision joins → fan out Phase 2.
- `NotificationEventProcessJob` / `NotificationEventsSweepJob` — Stage 3, unchanged.
- `config/recurring.yml`: snapshot_sweep :06, events_create (Stage 2) :18, events_sweep :33 (hourly). Stage 2 cadence is the consolidation-quality vs delivery-latency tunable.

**Scaling benchmark (2026-05-29, 100 orgs, REDUCED fan-out — components_per_ml 30-100, subscribers_per_ml 5-30):**
- 150 pending: Stage 1 20ms/snap (3.0s seq), Stage 2 0.54s (17.3K links, 1860 events), Stage 3 20ms/event (37.8s seq).
- 2000 pending: Stage 1 26ms/snap (51.8s seq, ~10s@5 workers), **Stage 2 7.56s** (255K links, 2040 events), Stage 3 58ms/event (119s seq, ~24s@5).
- Stage 2 scales LINEARLY at ~29.6µs/link. Extrapolated to PRODUCTION fan-out (~10× links, ~2.5M): **Stage 2 ≈ 75s+ (super-linear risk), breaches 11s, near 120s.**

**Conclusion:** Restoring the 120s timeout on Stage 2 was essential (would die at 11s default in prod). Stage 2 (single global txn) is the only non-horizontal stage and the scaling risk. Fix = **batch the claim+create into bounded transactions** (serial is fine — Stage 2 is hourly, ~2% of cadence; its only failure mode is timeout breach, which batching removes). Do NOT parallelize Stage 2 for speed: sub-linear (shared-table writes contend on one PG), and pointless vs the hourly cadence. Stage 1 + Stage 3 already carry the parallelism. 2000 pending is now stated as the daily-normal load (not a backlog edge case).

**Batching IMPLEMENTED (2026-05-29):** Stage 2 (`NotificationEventsCreateAllJob`) now claims+creates in bounded batches of `BATCH_SIZE` (default 200) whole MLs per transaction, looped (`distinct.limit(batch_size).pluck` → `DELETE … WHERE changed_monitoring_list_id IN (…) RETURNING` per batch). Whole MLs per batch preserves consolidation; each batch is its own bounded transaction (incremental commit on crash). `batch_size` is a private method (stubbable in tests). Deliberately NOT parallelized (hourly job, sub-linear gain from shared-table writes). All work (incl. this batching, the HTML artifact `notification_revision_pipeline.html`, 53 passing tests) lives on branch **`parallel-notification-item-phase-1`** (branched from `test`@864348208 which is kept intact), staged but NOT committed (per [[feedback-never-commit]] — Felix commits).

**REBASED ONTO main + Stage 2 PARALLELIZED per-ML (2026-06-08, branch `parallel-notification-item-phase-1`, full suite 1946 runs 0 failures).** Context: the original branch (off `test`) had its reviewed pieces (revision system, snapshot/create/sweep jobs, fixtures, migration `20260529000001`) ALL independently merged into `main`. The one piece NOT on main was the critical commit `c39eb641c "Try better parallel runs"` (the 3-stage pipeline + per-ML claim) — it was almost lost to a stale-local-branch rebase. Recovered it by reconciling against main, NOT replaying. Net diff vs main is now ONLY the pipeline delta.

Key change vs the earlier "do NOT parallelize Stage 2" conclusion above: Felix decided Stage 2's natural unit is ONE monitoring list ("does an event need to exist?" = "are there pending revision→ML links for this ML?"), so Stage 2 now FANS OUT instead of looping:
- `NotificationEventsCreateAllJob` → demoted to a **dispatcher**: `NotificationRevisionList.distinct.pluck(:changed_monitoring_list_id)` → `ActiveJob.perform_all_later(NotificationEventCreateJob.new(ml_id))`. No transaction, just enqueue-at-least-once.
- NEW `NotificationEventCreateJob(ml_id)` — per-ML unit: in one txn, `DELETE … WHERE changed_monitoring_list_id = ? RETURNING` claims THAT ML's links, builds one event + revision joins, fans out Stage 3. The per-ML claim is the concurrency guard (two jobs racing same ML: one claims rows, other no-ops). The old `BATCH_SIZE`/looped claim is GONE.
- NEW `NotificationPipelineRunJob` — synchronous orchestrator (Stage1→2→3) for manual/benchmark runs.
- DECISION: kept main's **object-based** `NotificationEventProcessJob#perform(event)` (recovered code/tests passed an id; adapted them to pass the object, matching main's reviewed delivery stage). with_lock + ON CONFLICT changes from the stale local HEAD were explicitly REVERTED per Felix.
- The unique index `index_ml_revisions_on_notification_and_range` on `(notification_id, version_range)` was folded into migration `20260529000001` (+ new `monitoring_list_notification_revision_lists` table). It broke 2 main `notification_item_test` cases that created an `eol` revision `4..4` duplicating fixture `eol_v4` ([4,4]→[4,5)); fixed by giving the test a distinct range (`1..3`). The index IS the recovered design's snapshot-race fail-safe — kept it.
- schema.rb hand-edited (revert-to-main + 3 additions) because re-dumping pulled in unrelated dev-DB drift; loaded into test DB via `db:test:prepare`.
- Caveat still standing: per-ML Stage 2 jobs all write the shared `monitoring_list_notification_events*` tables, so the old shared-write-contention concern theoretically applies — accepted as the tradeoff for horizontal Stage 2.
- HTML sequence diagram of the final flow at `tmp/notification_pipeline_flow.html` (gitignored). Staged, NOT committed (per [[feedback-never-commit]]).

Related: [[project-cleanup-deferred]], [[feedback-delivery-job-one-transaction]].
