---
name: project-keyset-sort-seed-scripts
description: Three .solve scripts seed and verify multi-page outlier sort data across every paginated endpoint
metadata: 
  node_type: memory
  type: project
  originSessionId: d4fe4ed5-4833-4921-85af-e2b3cd6fee9a
  modified: 2026-09-21T15:52:59.398Z
---

Built 2026-09-21 on branch `be-1123-4-keyset`, in `.solve/scripts/` (untracked, shared across
worktrees via symlink):

- `seed_sortable_pagination_data.rb` — 130 records per resource for all 19 paginated endpoints plus
  their relationship endpoints, with tie runs of 60 identical values (guaranteed to straddle a
  size-50 page boundary), `''`/NULL runs, and collation outliers.
- `check_keyset_sorting.rb` — walks every sort key both directions at page sizes 1/3/7/50 through
  the real `Keyset::Page`, comparing concatenated pages against the unpaginated query. 834 PASS.
- `check_sort_requests.rb` — fires real HTTP requests for the sort/cursor edge cases.

**Constraints that shaped the seed, each hit at runtime:**
- `components` has a partial unique index on `(name, version_info, vendor)` `WHERE active AND
  last_successful_sync_at IS NOT NULL` — so each of the three needs its own offset tie run, or the
  rows must be inactive. Empty `name`/`vendor`/`version_info` are only valid when `active: false`.
- `ApiToken::PER_USER_TOKEN_LIMIT` = 50 per membership; `MonitoringList::Export::MAX_DAILY_EXPORTS`
  = 50 per membership per rolling day (backdate earlier batches to get past it).
- `User#siemensid_limits` (on create) rejects `_`, control chars and >59-char name parts, so user
  names need a reduced outlier set.
- `ComponentRequest` `component_name`/`version` have `length: {minimum: 1}`; `MonitoringList#name`
  and `Notification#title` need presence — their "blank" outlier must be a space or a distinct value.

**`Current.set` must wrap the transaction, not the reverse.** With the transaction outermost, the
`Current` block exits before COMMIT, so `after_commit` callbacks run unscoped and
`Inbox::Item#membership` resolves to nil — `after_destroy_commit { membership.destroyed? }` in
`app/models/inbox/item.rb` then raises `NoMethodError`. A `DRY_RUN` rollback hides this entirely,
since `after_commit` never fires.

**`dependent: :destroy` runs `Inbox::Item` → itemable only.** Destroying the event or itemable
leaves orphaned `Inbox::Item` rows with a dangling `itemable_id`; destroy the items first.

Related: [[project-keyset-cursor-trust-model]], [[feedback-test-deletion-pattern]]
