---
name: script-migrate
description: >-
  See what a data migration actually does to real rows before committing it. Primary path is the
  team-mandated manual run: reset the DB to the branch's base with fixture data, snapshot exactly
  the rows the migration touches, run the real `bin/rails db:migrate`, snapshot again, and read the
  before/after yourself — the skill locates the affected tables, names the fixture records worth
  looking at, and hands over copy-paste SQL for `bin/rails dbconsole -p` (`\e` opens an editor) or
  `bin/rails console`, but never renders the verdict. Secondary path, for edge cases fixtures do not
  cover: a throwaway script that invokes the migration's real `up`/`down` inside a rolled-back
  transaction against seeded old-schema rows. Use whenever the user asks to run / exercise / prove /
  demo / inspect a migration, check a before-after diff, or find which fixtures a migration touches —
  not for writing or generating a migration (that's `bin/rails generate migration`, see
  .claude/rules/050-migrations.md), not for seeding records to browse in the dev DB (that's the
  script-seed skill), and not for benchmarking queries (that's the script-performance skill).
---

# Script: Migrate

Two paths, and **Procedure A is the default**.

**Procedure A — the mandated manual run.** Team rule: every migration is run locally
against the base branch's fixture data, and the changed data is inspected **manually, by the
developer**. No AI verdict, no script that says "looks fine" — a human reads the before and after.
Reviewers do not do this for you. Your job here is preparation and legwork: find which tables and
rows the migration touches, name the fixture records worth watching, hand over the exact SQL, and
then get out of the way. State what changed factually if asked; never conclude "the migration is
correct".

**Procedure B — the rolled-back script.** For edge cases the fixtures do not contain (a deleted
association, a null, a boundary value), a throwaway script reverses the migration inside a
transaction, seeds those rows in the old schema, runs the real `up`, and rolls back. It is a
supplement to A, not a replacement — and it is unavailable when the migration is
`IrreversibleMigration` or `disable_ddl_transaction!`.

Sibling skills: **script-seed** (records to browse), **script-performance** (query cost).

## Procedure A — manual before/after against fixture data

### A1. Read the migration and list what it touches

Open the migration and write down, per this repo's investigation-before-action rule:

- Every **table** it reads or writes, and every **column** it adds, drops, renames, or backfills.
- The *data* transformation, not just the schema change — the `unnest`, the `LEFT JOIN`, the parse.
- Whether it is `IrreversibleMigration` or `disable_ddl_transaction!` (rules out Procedure B).

### A2. Reset to the base branch with fixture data

Run the **db-reset** skill. It checks out the base (main, or the parent branch when stacked),
loads fixtures *there*, switches back, and only then migrates. Do not skip to `db:migrate` on a DB
whose fixtures already reflect the new schema — the migration would have nothing left to transform
and the whole exercise proves nothing.

Stop **before** the final `bin/rails db:migrate` — you need the before-snapshot first. With
`vil-db-reset` that means running its two halves by hand, since the script migrates at the end.

### A3. Find the fixtures the developer should look at

This is the legwork that makes manual inspection cheap. For each table from A1, locate its fixture
file and name the specific records.

Fixture files are **namespaced by directory**, not flat — `test/fixtures/inbox/`,
`notification/`, `monitoring_list/`, `billing/` — and a model with `self.table_name` does not match
its file name at all (see the `_fixture model_class` pattern). So resolve the file from the model:

```bash
find test/fixtures -name '*.yml' | grep -i <model_or_table_stem>
```

Then report to the developer, per affected table:

- The fixture file path and how many records it holds.
- The **fixture label** of each record whose migrated column is interesting — the ones with a
  non-empty value, a null, a deleted association, a boundary value.
- **Whether the fixtures actually cover the transformation at all.** If every row's source column
  is empty or uniform, the manual run will show a before/after of nothing. Say that outright and
  offer either adding a fixture or falling back to Procedure B — do not let a vacuous run pass as
  a proof.

### A4. Capture the BEFORE snapshot

Hand the developer a query per affected table, selecting the primary key plus only the columns the
migration touches, ordered deterministically so the two snapshots line up:

```sql
SELECT id, priorities FROM subscriptions ORDER BY id;
```

Run it in a SQL console — `bin/rails dbconsole -p`. Inside psql:

- `\e` opens `$EDITOR` for a multi-line query (much nicer than typing it on one line)
- `\x` toggles expanded row display, for wide rows
- `\pset pager off` stops results disappearing into the pager
- `\o /tmp/before.txt` tees results to a file, `\o` alone switches back to the screen
- `\pset null '<NULL>'` and `\pset format unaligned` — otherwise NULL and `''` print alike and the
  diff hides a backfill

Tee both snapshots to files so the developer can read them side by side. Use `bin/rails console`
instead when the interesting value only makes sense through the model (a serialized column, an
enum, an association) — otherwise prefer raw SQL, which shows the stored value rather than what AR
casts it to. In the console, run `Current.without_organization_and_membership_scopes` first and
query `TlpAmberStrict` models through `including_tlp_amber_strict`, or the default scopes hide rows
(Readme.md "Manual testing").

### A5. Run the real migration

```bash
bin/rails db:migrate
```

The real thing, destructively, on the dev DB — that is the point. No script, no transaction.

### A6. Capture AFTER and hand it over

Rerun the same query into `/tmp/after.txt`. If the migration renamed or dropped the column, adjust
the column list and say so explicitly, since the two snapshots are then not textually diffable.

Then check reversibility and the schema diff (Readme.md "Manual testing", step 4):

```bash
bin/rails db:rollback STEP=<number of migrations on your branch>
bin/rails db:migrate
git diff db/schema.rb
```

Present the two snapshots (or `diff -u /tmp/before.txt /tmp/after.txt`), the fixture labels from
A3 and the rollback output, and stop there. The developer reads it and decides. Do not summarise it as correct, do not
assert the migration works — describing what changed is the most you may do, and only when asked.

## Procedure B — rolled-back script for uncovered edge cases

Reach for this only after A, and only when the fixtures cannot express the case you need. It is
also the fallback when the pre-migration schema is otherwise unreachable. Note that replaying the
migration's SQL by hand instead only *mimics* the migration and drifts the moment it changes —
invoke the real `up`.

### B0. Reuse before you write

Same as script-seed Step 0: `ls .solve/scripts/` first. If a migration-demo script for a nearby
migration already exists, copy and retarget it rather than rebuilding the reverse-then-seed-then-up
dance from scratch. Only write a brand-new one when nothing fits.

### B1. Read what the migration actually does — don't guess

Open the migration file(s) and identify the *data* transformation, not just the schema change.
Per this repo's investigation-before-action rule, read the real `up` (and `down`) before writing a
line of the script. Note specifically:

- The exact SQL/AR the `up` runs on data (an `unnest`, a `LEFT JOIN`, a backfill `UPDATE`), because
  that behavior — not your summary of it — is what you're proving.
- Whether **other, later migrations** have since moved past this one (renamed the table, dropped a
  column). Reaching the pre-migration state means reversing those later migrations first, in
  reverse order, before reversing the one under test.
- Whether the migration declares `disable_ddl_transaction!` (concurrent index creation, etc.) or a
  `down` that raises `IrreversibleMigration`. Either one kills the rollback trick — there is no
  Procedure B for such a migration, only Procedure A.

### B2. Invoke the real migration inside a rolled-back transaction

`require` the migration file by its full path, then call `.new.migrate(:down)` / `.new.migrate(:up)`
(`.new.up` silently does nothing on a `change`-only migration), wrapped
in `ActiveRecord::Migration.suppress_messages { }` to keep the output clean. Wrap everything in a
transaction whose last statement is `raise(ActiveRecord::Rollback)`, so nothing persists:

```ruby
require(Rails.root.join('db/migrate/20260709090000_move_admin_expiry_to_inbox_item_namespace'))
require(Rails.root.join('db/migrate/20260708120001_create_membership_admin_expiry_entries'))

ActiveRecord::Base.transaction do
  ActiveRecord::Migration.suppress_messages do
    MoveAdminExpiryToInboxItemNamespace.new.migrate(:down)   # reverse later migration first
    CreateMembershipAdminExpiryEntries.new.migrate(:down)    # then the one under test
  end

  # ... seed old-schema rows (B3), then run the real up ...

  ActiveRecord::Migration.suppress_messages { CreateMembershipAdminExpiryEntries.new.migrate(:up) }

  # ... inspect (B4) ...
  raise(ActiveRecord::Rollback)
end
```

Because Postgres DDL is transactional, the reversed schema, the seeded rows, and the re-applied
migration all vanish on rollback — the DB is exactly as it was before the script ran.

**When the migration only adds a column, the reverse is trivial** — no later migration to unwind,
just `down` then `up`. But because that column already exists in your live DB, you must run `down`
*first*, or the real `up`'s `add_column` raises "column already exists".

**Reset the column cache after any column change.** `add_column`/`remove_column`/rename leaves the
model's cached schema stale the instant `down`/`up` runs, so a later `reload` or attribute read
still uses the old columns and silently misses the new one. Call `Model.reset_column_information`
on each affected model after the `up`, before you read transformed rows through AR:

```ruby
ActiveRecord::Migration.suppress_messages do
  AddExpiryNotifiedAtToMemberships.new.migrate(:down)   # column exists in your DB → down FIRST
  AddExpiryNotifiedAtToMemberships.new.migrate(:up)     # then the real up re-adds it + backfills
end
Membership.reset_column_information           # else membership.reload.expiry_notified_at is unseen
```

### B3. Seed the pre-migration state with the edge cases you're proving

After the `down`s you're in the *old* schema (old table name, old columns). Seed one row in that
old shape holding exactly the cases the migration must handle. Source edge cases from the schema and
tests rather than inventing them (script-seed Step 1). The canonical pair for a "preserves X"
proof is **one existing id and one deleted (non-existent) id**:

```ruby
real = Current.without_organization_and_membership_scopes { Membership.first.id }
fake = SecureRandom.uuid   # a since-deleted membership: no row matches it
summary_id = ActiveRecord::Base.connection.insert(<<~SQL.squish)
  INSERT INTO membership_admin_expiry_summary_items (organization_id, remind_until, membership_ids, created_at, updated_at)
  VALUES (#{Organization.first.id}, now() + interval '1 day', ARRAY['#{real}','#{fake}']::uuid[], now(), now())
SQL
```

**Org-scoping gotcha**: most models are
`OrgScoped`, whose `default_scope` filters by `Current.organization`. With no `Current` set,
`Membership.first` returns `nil` even when the table is full. Wrap the lookup in
`Current.without_organization_and_membership_scopes { }` — never `.unscoped`, which is banned even
in scratch (`.claude/rules/010-multi-tenant-scoping.md`). `Organization` is the tenant root, not
`OrgScoped`, so `Organization.first` needs no bypass.

### B4. Prove it by querying the transformed rows back, not by trusting `up`

`up` not raising says nothing about whether the data landed the way you expect. Query the produced
rows and print fed-in vs. produced — the count (to prove no rows were dropped or duplicated) and
each row's key fields (to prove the transformation):

```ruby
rows = ActiveRecord::Base.connection.select_all(<<~SQL.squish)
  SELECT id, membership_id FROM inbox_item_membership_expiry_summary_entries
  WHERE membership_expiry_summary_id = #{summary_id} ORDER BY membership_id NULLS LAST
SQL
puts("fed in: #{real} (exists), #{fake} (deleted)")
puts("entries created: #{rows.count}")
rows.each { |r| puts("  entry #{r['id']} -> membership_id=#{r['membership_id'].inspect}") }
```

The proof reads directly off the output: one entry per fed-in id (no drops), the existing id's
`membership_id` preserved, the deleted id collapsed to `nil` (the `LEFT JOIN` miss).

**Read back through AR when the model loads — not hand-parsed SQL.** Once you've called
`reset_column_information` (B2), `record.reload.new_column` is clearer than `select_all` plus
string parsing, and hands you typed values (a real `TimeWithZone`, not a string) you can compare
directly. Reach for raw `select_all` only when the pre-migration schema has no usable model.

**Assert timestamps exactly — don't recompute the clock.** To check a backfill that stores
`MAX(created_at)`, compare against the *same* value you seeded, never a fresh `5.days.ago` evaluated
at assert time — the two differ by however long the script ran, which forces a fudge like
`(actual - expected).abs < 2`. Capture the value once, pinned to whole seconds so it survives the
DB round-trip at microsecond precision, and reuse it on both sides for a plain `==`:

```ruby
reported_at = 5.days.ago.change(usec: 0)                 # whole seconds → exact round-trip
seed_summary(membership, created_at: reported_at)
# ... run up, then Membership.reset_column_information ...
raise unless membership.reload.expiry_notified_at == reported_at   # exact, no abs<tolerance
```

### B5. Run it against fixture state too

The seeded row proves the mechanism; the fixtures are the representative dataset. Run the same
script under `RAILS_ENV=test` with fixtures loaded — `RAILS_ENV=test bin/rails db:fixtures:load`,
then `RAILS_ENV=test bin/rails runner .solve/scripts/<name>.rb`. The rolled-back transaction means
the fixtures survive for the next run.

This does **not** replace Procedure A. A script asserting its own expectations is not a human
reading a before/after, and the team rule asks for the latter.

### B6. Place, run, and lint it — same as the siblings

Identical to script-seed Steps 6 and 8:

- Write it to `.solve/scripts/<name>.rb` (git-excluded; symlinked across worktrees). Run with
  `bin/rails runner .solve/scripts/<name>.rb`, or `RAILS_ENV=test bin/rails runner ...` for the
  fixture variant.
- If the migration is `disable_ddl_transaction!` or `IrreversibleMigration` (B1), the rollback
  trick can't hold it — there is no Procedure B. Do Procedure A and inspect the persisted result.
- Lint the file: `bin/rubocop -A .solve/scripts/<name>.rb` and
  `bin/editorconfig-checker .solve/scripts/<name>.rb`, run from the repo root against the relative
  path. Report both outcomes.

## Reference example (Procedure B)

A Procedure B run for `CreateMembershipAdminExpiryEntries#up` reverses
both `20260709090000_move_admin_expiry_to_inbox_item_namespace` and
`20260708120001_create_membership_admin_expiry_entries` to reach the old
`membership_admin_expiry_summary_items` table with its `membership_ids` uuid array, seeds one row
holding `[existing id, deleted id]`, invokes the real `up`, and prints the two resulting
`inbox_item_membership_expiry_summary_entries` — one with the membership id preserved, one collapsed
to `nil` — all inside a rolled-back transaction. Browse `.solve/scripts/` for a script to
copy from (B0).
