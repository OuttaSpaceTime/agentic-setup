---
name: project-local-helpers-manual-worktree-sync
description: The untracked console/migration helper files are per-worktree copies and must be synced by hand
metadata: 
  node_type: memory
  type: project
  originSessionId: 8bceb75d-e945-4f27-a93f-372d71f344c7
  modified: 2026-10-29T19:15:50.885Z
---

These files are listed in the repo's `info/exclude`, so they are untracked and do **not** travel between worktrees with git. Each worktree holds its own copy and they drift:

- `config/initializers/fixture_console_helpers.rb`
- `config/initializers/scope_console_helpers.rb`
- `config/initializers/migration_scope_guard.rb`
- `test/local/` (whole directory)

Main worktree is `/home/felix/Code/Vilocify/vilocify-portal`; feature worktrees live under `/home/felix/Code/Vilocify/worktrees/`.

When one of these is improved in a worktree, copy it to main explicitly — Felix asks for this. On 2026-08-11 main was five months stale on `fixture_console_helpers.rb` (missing the IRB label completion and `#fixture_name`) and lacked `test/local/fixture_console_helpers_test.rb` entirely. Diff before copying: `test/local/` also holds per-branch migration tests that must not be clobbered or deleted (main had `backfill_item_type_cache_test.rb` that no other worktree had).

Never `git add` any of them.

`bin/test` and `.simplecov` do NOT drift either: since 2026-10-29 `_link_claude` symlinks them to main too (all 12 worktrees switched; their copies were identical to main's). `bin/quality` is still copied.

`.claude/` and `CLAUDE.md` do NOT drift any more. Since 2026-10-28, `worktree.sh` `_link_claude` symlinks both to main (Felix chose symlink over copy+sync), and all existing worktrees were switched; the old copies are in `~/Code/Vilocify/.worktree-claude-copies-2026-10-28/`. Before that, copied `.claude` snapshots lagged: worktrees missed the 2026-10-27 hooks, and stale rule 800 kept agents running editorconfig after its removal. `CLAUDE.md` was never copied, so 95 of 96 worktree sessions never loaded it. So edit `.claude/` and `CLAUDE.md` in main only; the files listed above are still per-worktree copies.

A stale `test/local/` migration test breaks every whole-suite run in that worktree: on 2026-09-16 the `be-1123-*` worktree carried `test/local/add_cached_user_fields_to_memberships_test.rb`, which `require`s `db/migrate/20260911104738_add_cached_user_fields_to_memberships.rb` — a migration from another branch, absent there. Minitest aborts with a `LoadError` while *loading* tests, so `bin/test` with no args, `bin/test --affected` (which falls back to the full suite) and directory arguments all die before a single test runs. Scoped `bin/test <files>` still works. Delete or move the orphaned local test when its branch is gone.

Related: [[project-load-console-logger-leak]], [[project_worktree_db_isolation]], [[project_migration_scope_guard]]
