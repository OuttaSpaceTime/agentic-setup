---
name: project_worktree_db_isolation
description: "Each git worktree runs isolated dev+test DBs via a skip-worktree'd database.yml; main keeps bare names"
metadata: 
  node_type: memory
  type: project
  originSessionId: 2e2fceeb-cfd9-46dc-8657-b1bd12058bb1
---

Each git worktree gets its own dev + test databases inside the single shared Docker Postgres (`vilocifyportal-postgres-1` on `127.0.0.1:5433`). The `create-worktree` skill (step 6) writes `vilocify_portal_{dev,test}_<slug>_<pathhash>` into the worktree's `config/database.yml`, then runs `git update-index --skip-worktree config/database.yml` so the edit is hidden from git (clean `git status`, can never be committed). The main checkout keeps the bare `vilocify_portal_dev` / `vilocify_portal_test`. `vil-db-reset` (in `~/Code/Vilocify/.bin/`, outside the repo) and the `db-reset` skill resolve the dev DB name dynamically via `bin/rails runner -e development 'print ActiveRecord::Base.connection_db_config.database'` instead of hardcoding it.

**Why:** worktrees previously shared `vilocify_portal_dev`/`_test`, so a migration or `bin/rails test` in one worktree clobbered the main checkout and every other worktree, and parallel test runs raced on the same `vilocify_portal_test_*` worker DBs. dotenv is NOT loaded by this Rails backend (no `dotenv-rails` in the Gemfile — `.env*` are frontend-only), and `config/database.yml` is a tracked file, so `--skip-worktree` is the only no-commit way to override the DB name. Verified end-to-end 2026-06-10: 814-test parallel run green, exactly 20 suffix-scoped worker DBs created, no bare-worker leakage, main checkout byte-for-byte unchanged.

**How to apply:** If a worktree's `config/database.yml` looks modified but `git status` is clean, that's the intended skip-worktree isolation — do not "fix" it. db:prepare in the development env creates AND schema-loads both dev and test (no separate test-env prepare needed). Before `git worktree remove`, drop the worktree's DBs (`bin/rails db:drop` + pattern-drop the `_<suffix>_<N>` workers, scoped to that worktree's test DB name) to avoid orphans piling up in the shared instance. If `config/database.yml` ever changes upstream, the skip-worktree bit blocks the merge: `git update-index --no-skip-worktree config/database.yml`, reconcile, then re-run step 6. Suffix = 20-char slug of the worktree dir + 6-char md5 of its path, keeping `vilocify_portal_test_<suffix>_<N>` under PostgreSQL's 63-char identifier limit.
