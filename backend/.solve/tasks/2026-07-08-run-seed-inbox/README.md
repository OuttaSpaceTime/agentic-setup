# Run the many-inbox-items seed

Runs `.solve/scripts/seed_many_inbox_items.rb` against the dev DB to create ~50
inbox items for superuser@example.com (admin in Organization A) — 3 pages on the
index. Idempotent (`find_or_create_by!`).

- `01-dry-run-seed-many-inbox-items.sh` — DRY_RUN, rolls back, prints the count.
- `02-run-seed-many-inbox-items.sh` — real run, persists.

Verify: log in as superuser in Organization A and open the inbox index.
