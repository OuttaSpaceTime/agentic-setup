# Worktree DB cleanup check

Question: do per-worktree databases ever get cleared, or do they orphan?

- `01-list-dbs.sh` — list all databases in the shared Docker Postgres (:5433),
  then list current git worktrees. If there are `vilocify_portal_dev_*` /
  `_test_*` DBs whose suffix maps to no live worktree, they are orphans =>
  not auto-cleared.

Run: `bash .solve/tasks/2026-07-23-worktree-db-cleanup/01-list-dbs.sh`
Verify: eyeball db count vs worktree count.
