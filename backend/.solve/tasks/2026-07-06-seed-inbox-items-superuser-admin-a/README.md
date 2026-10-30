# Seed 100 inbox items on superuser_as_admin_in_a

Goal: give the `superuser` / admin / Organization A membership 100 `Inbox::Item`
rows so the inbox list has enough data to page through in the browser.

## Scripts

- `01-inspect_current_state.rb` — run via `bin/rails runner`. Prints the
  membership's id, its `inbox_items_count` counter-cache value, and the real
  count of `Inbox::Item` rows currently in the DB for it (these can differ
  since fixtures set counters without backing rows). Read-only, no writes.
- `02-inspect_existing_item_types.rb` — run via `bin/rails runner`. Groups
  existing `Inbox::Item` rows for the membership by `item_type_cache`.
  Read-only, no writes.
- `03-dry_run_seed_script.sh` — runs `script/seed_inbox_items_for_superuser_admin_in_org_a`
  with `DRY_RUN=1` so it rolls back, to check the remaining-count logic
  before running for real.
- `04-run_seed_script_for_real.sh` — runs the seed script for real (no
  `DRY_RUN`), persisting the new inbox items.
