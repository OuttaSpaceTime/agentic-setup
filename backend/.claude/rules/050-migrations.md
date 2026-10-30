---
paths:
  - "db/migrate/**"
  - "db/schema.rb"
---

# Migrations

## Generated, Never Hand-Written

- Never write a migration file by hand (Write/Edit). Always run `bin/rails generate migration <Name> <fields>` so Rails assigns the timestamp/version correctly.
- After generating, edit the generated file's body as needed — but do not create the file or its filename/timestamp yourself.
- The `ActiveRecord::Migration[X.Y]` version in a generated file must match the Rails version actually in use (check `Gemfile.lock` for `rails (X.Y.Z)` if unsure) — do not assume or copy a version from an older migration.
- Never edit `db/schema.rb` by hand; `bin/rails db:migrate` writes it. The team's `.opencode/plugins/protected-files.js` blocks both hand-made migration files and hand edits to `db/schema.rb`.

<example type="invalid">

Writing `db/migrate/20260706153340_create_foo.rb` directly with the Write tool.

</example>

<example>

Running `bin/rails generate migration CreateFoo name:string` as a task script, then editing the resulting file's body.

</example>

## Data Migrations Live in Their Own Migration

- A migration either changes the schema or changes data, never both. Add the columns in one, backfill in the next, add the constraints and indexes in a third.
- Split for reversibility. `db:rollback` steps back exactly one migration, so a combined one is all-or-nothing, while a split lets you revert the indexes, the data and the columns independently — and keeps each `down` small enough to be obviously correct.
- This holds even when the migration keeps its transaction. Combining is not unsafe on its own — a transactional migration rolls the DDL back too — but the backfill can no longer be re-run alone when it fails, and a model touched earlier in the migration keeps a stale column cache across `add_column`.
- Write the backfill as one set-based SQL statement (`UPDATE … FROM`), following `MigrateCvssVectors` and `MigrateCVERecordsToArray`. No models: their default scopes silently skip rows (`OrgScoped` finds nothing without `Current.organization`, `TlpAmberStrict` hides restricted records).
- A migration that destroys data cannot be reversed; mark it with `def down; raise(ActiveRecord::IrreversibleMigration); end` (Readme.md "Reversibility").
- A data migration defines `def up`, not `change` with an `up_only` block. Give a backfill a `def down` that undoes it when the old values can be restored, e.g. it filled columns that were NULL before. Often they can't (the `UPDATE` overwrote what was there); then leave it `up`-only. Verified on Rails 8.1.3.1: with no `def down`, `db:rollback` prints `reverting`/`reverted` and does nothing — the same silent no-op `up_only` gives, without the wrapper — so `db:rollback STEP=<n>` still works. `IrreversibleMigration` is raised only by a non-invertible `change`.

<example type="invalid">

```ruby
def change
  up_only do
    execute("UPDATE components SET vendor = '' WHERE vendor IS NULL")
  end
end
```

</example>

<example>

```ruby
# Restorable: the columns were added empty one migration earlier
def up
  execute("UPDATE memberships SET user_email = users.email FROM users WHERE users.id = memberships.user_id")
end

def down
  execute('UPDATE memberships SET user_email = NULL')
end

# Not restorable: the original NULLs are indistinguishable from real '' afterwards, so up only
def up
  execute("UPDATE components SET vendor = '' WHERE vendor IS NULL")
end
```

</example>

<example type="invalid">

```ruby
def up
  Membership.expired.count                        # loads the column cache
  add_column(:memberships, :user_email, :string)
  Membership.column_names.include?('user_email')  # => false, needs reset_column_information
end
```

</example>

## No Lock-Avoiding Techniques

- Deploys stop the app while migrations run (Readme.md "Deployment"), so no `algorithm: :concurrently`, no `disable_ddl_transaction!`, no batched updates. Every migration keeps its transaction.

<example type="invalid">

```ruby
class AddCachedUserFieldsToMemberships < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    change_table(:memberships, bulk: true) { |t| t.string(:user_email) }
    execute('UPDATE memberships SET user_email = ...')
    change_column_null(:memberships, :user_email, false)
    add_index(:memberships, %i[organization_id user_email id], algorithm: :concurrently)
  end
end
```

</example>

<example>

```text
AddCachedUserFieldsToMemberships                    # columns
BackfillCachedUserFieldsOnMemberships               # UPDATE ... FROM
AddCachedUserFieldConstraintsAndIndexesToMemberships # NOT NULL + plain add_index
```

</example>

## Run Every Migration You Write

Never report a migration as done from reading it. Before handing it back:

- Run `bin/rails db:migrate`, then `bin/rails db:rollback STEP=<number of migrations on your branch>` and migrate forward again — this is what catches a `change` block Rails cannot invert.
- Check `git diff db/schema.rb` and confirm it shows only the intended change. When a migration is being restructured, the diff against the old version must be the schema version line and nothing else.
- A data migration also gets a `test/local/` test (see `320-migration-tests.md`), mutation-verified: break the statement, confirm the test goes red, restore it.
- Your run does not replace the developer's: they must run and check every migration before the MR (Readme.md "Writing migrations"). Hand over the before/after (script-migrate skill), never a verdict.

## Recovering a Failed Migration

- Never run `bin/rails db:rollback` after a migration raised. The failed migration wrote no `schema_migrations` row, so Rails cannot see it and `STEP=1` reverts the *previous, successful* migration instead. `db:rollback` is for deliberately reverting a migration that succeeded.
- A `down` does not help either. Rails looks the version up in `schema_migrations` before calling it, so even a correct `down` is never invoked — and `db:migrate:down VERSION=…` is a silent no-op for the same reason.

| Migration | State after a raise | Recovery |
|-----------|---------------------|----------|
| transactional (all of ours) | clean — the schema change and the version row rolled back together | fix it, `bin/rails db:migrate` |
