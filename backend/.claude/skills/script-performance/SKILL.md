---
name: script-performance
description: >-
  Write a throwaway Ruby script that measures the cost of a query against a realistic
  vilocify-portal dataset — query counts, an N+1 fix, worst-case latency — non-destructively, by
  seeding thousands of rows inside a rolled-back transaction so nothing persists. Covers counting
  `sql.active_record` queries around a block, finding the worst-case (heaviest) row to measure,
  and proving an N+1 fix by running the same read naive vs. with `includes` and comparing query
  counts. Use this whenever the user asks to measure/benchmark a query, prove or reproduce an N+1,
  count how many queries an endpoint/serializer fires, or check worst-case latency against seeded
  data — not for seeding records to browse in the dev DB (that's the script-seed skill) and not
  for the checked-in bulk seeder (lib/database_seeder.rb).
---

# Script: Performance

A recipe for measuring — not leaving behind — data. The point is to answer "how many queries does
this fire?" / "did my `includes` actually kill the N+1?" / "how slow is the worst-case row?"
against a realistic dataset, without polluting the dev DB. This is the measurement sibling of the
**script-seed** skill; where that one persists records for manual QA, this one seeds inside a
transaction that always rolls back.

Everything about *where* the script lives, *how* it runs, and the app's standing gotchas is shared
with script-seed — read these sections of it rather than duplicating them here:

- **Step 3 — standing gotchas** (multi-tenant `OrgScoped`/`Current` scoping above all).
- **Step 6 — place it in `.solve/scripts/`** and run with `bin/rails runner`.
- **Step 8 — run the quality tools** (`rubocop -A` + `bin/editorconfig-checker` on the file).

The two `seed-and-measure-*.rb` exemplars already in `.solve/scripts/` show the full shape — start
by browsing those (script-seed Step 0: reuse before you write).

## The measurement-specific pieces

- **Seed inside a rolled-back transaction.** Wrap the whole run in
  `Current.without_organization_and_membership_scopes { ActiveRecord::Base.transaction { …; raise(ActiveRecord::Rollback) } }`
  and build the dataset with `DatabaseSeeder.new(…).run` inside it. Nothing persists, so you can
  measure against thousands of rows without polluting the dev DB. Unlike script-seed's `DRY_RUN`
  gate (a persist-by-default seed), here the rollback is unconditional.
- **Count queries, don't guess.** Subscribe to `sql.active_record`, skip `SCHEMA` and
  `BEGIN/COMMIT/SAVEPOINT/RELEASE` rows, and return `[query_count, seconds]` around a block. This
  is what turns "feels faster" into "12 queries → 2".
- **Find the worst-case row to measure.** Don't measure a random record; order by whatever makes a
  row heavy and `pick` its id — `order(Arel.sql('cardinality(membership_ids) DESC'))` for an array
  column, or a `JOIN … GROUP BY … ORDER BY COUNT(*) DESC` for a fan-out join table.
- **Prove an N+1 fix by running the read twice.** Same read naive vs. with `includes`, print both
  query counts side by side — equal output plus fewer queries is the evidence a preload works.
