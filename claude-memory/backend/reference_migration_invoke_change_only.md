---
name: reference-migration-invoke-change-only
description: Invoke a migration in a proof script with migrate(:up)/migrate(:down), not .new.up — change-only and up_only migrations need it
metadata:
  type: reference
---

For Procedure B migration-proof scripts, call `MyMigration.new.migrate(:up)` / `migrate(:down)`,
not `.new.up` / `.new.down`.

`ActiveRecord::Migration#exec_migration` (activerecord-8.1.3.1 `migration.rb:990`) is what handles
a `change`-only migration: it runs `change` for `:up` and `revert { change }` for `:down`. Calling
`.new.up` bypasses it. `up_only` blocks depend on this too — `up_only` runs `unless reverting?`
(`migration.rb:933`), and `reverting` is set by the `revert` path.

Verified in-session (BE-1279): `migrate(:down)` on a `change_table(bulk: true)` migration using
`t.change_null(false)` + `t.change_default(from:, to:)` inverts correctly, runs inside an
enclosing `ActiveRecord::Base.transaction`, and rolls back cleanly. `.solve/scripts/prove_expiry_notified_at_backfill.rb`
uses `.new.up` only because that migration defines explicit `up`/`down`.

Related: [[feedback-migrations-must-be-generated]], [[reference-psql-null-vs-empty]]
