---
name: project-migration-scope-guard
description: Local-only runtime MigrationScopeGuard replaced the git-ignored RuboCop migration cop on 2026-08-07
metadata: 
  node_type: memory
  type: project
  originSessionId: 63dcdf5b-d2d2-4c4b-8551-c580261c5654
  modified: 2026-08-07T10:00:32.423Z
---

On 2026-08-07 the git-ignored local RuboCop setup (`.rubocop-local.yml`, `bin/rubocop-local`, `.local/cops/unscoped_migration_query.rb`) was deleted and replaced by a runtime guard, because static analysis was not deterministic enough — Felix wanted it to fire on an actually-wrong migration run locally.

Both files are **untracked** (listed in `.git/info/exclude`) so nothing in the repo reveals them:

- `config/initializers/migration_scope_guard.rb` — prepends `CaptureSql` to `ActiveRecord::Migration#exec_migration` (subscribes to `sql.active_record`, raises `MigrationScopeGuard::Violation` after the body), and prepends `CurrentConstant` to `ActiveRecord::Migration::Current.singleton_class` (raises when a bare `Current` gets an app-`Current` method — bare `Current` resolves to `ActiveRecord::Migration::Current`, not `::Current`).
- `test/local/migration_scope_guard_test.rb` — 12 tests, picked up by `bin/rails test` via the default `test/**/*_test.rb` glob.

Both are copied into new worktrees via `CONFIG_FILES` in `.claude/skills/create-worktree/scripts/worktree.sh`. Documented in `.claude/rules/320-migration-tests.md`.

**Two design decisions Felix made, worth not re-litigating:**

1. **Pure SQL matching — no `ApplicationRecord.descendants`.** An earlier version looked up whether the table belonged to an `OrgScoped` model. Dropped: it was fail-open (unknown table = allowed) and invited the autoloading question. Any `"<table>"."organization_id" IS NULL` now aborts. Measured cost: zero false positives across the entire migration history; a future deliberate null-org query (only `billing_consumption_periods` has a nullable `organization_id` while not being `OrgScoped`) would be flagged. The regex anchors on Arel's quoted `"table"."column"` form, so hand-written SQL in a migration is never matched.
2. **`TlpAmberStrict` is covered too**, and it must be **bind-aware**: dev inlines the predicate as `= FALSE`, the test env binds it as `= $1`. Matching the literal alone silently did nothing under test. `skips_restricted_rows?` checks the literal OR `payload[:binds]` for `tlp_amber_strict == false`. That also keeps `including_tlp_amber_strict.where(tlp_amber_strict: true)` legal. Note `excluding_tlp_amber_strict` is NOT an escape hatch — it re-emits the same predicate.

Caveats: raises after the migration body, so a `disable_ddl_transaction!` migration is not rolled back; only code paths that actually execute are seen; `synced_at_least_once` and `ApiToken`'s nil-membership scope remain uncovered.

Related: [[reference_default_scope_write_precedence]], [[feedback_rubocop_disable]], [[project_worktree_db_isolation]]
