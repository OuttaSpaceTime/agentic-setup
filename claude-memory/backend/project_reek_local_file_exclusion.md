---
name: project_reek_local_file_exclusion
description: "Local-only Ruby files are kept out of reek by a git-derived file list in bin/quality, never by .reek.yml exclude_paths"
metadata:
  type: project
---

`.reek.yml` is tracked and must stay pristine — no `exclude_paths`, no `--skip-worktree`. Instead the untracked `bin/quality` runs

```sh
bundle exec reek $(git ls-files --cached --others --exclude-standard -- 'app/*.rb' 'lib/*.rb' 'config/*.rb' 'test/*.rb')
```

so anything listed in `.git/info/exclude` (`config/initializers/{fixture_console,scope_console}_helpers.rb`, `migration_scope_guard.rb`, all of `test/local/`) is skipped automatically. Tracked `bin/reek` still walks the bare `app lib config test` dirs and is what CI runs (`.gitlab-ci.yml`) — locally always use `bin/quality`, never `bin/reek`.

**Why:** the earlier fix was an `exclude_paths:` block hand-added to `.reek.yml` plus `git update-index --skip-worktree`. `.reek.yml` is a reek `--todo` dump that changes upstream often, and a skip-worktree'd file blocks `git pull`/checkout every time it does. The git-derived list also needs no maintenance: it caught three `test/local/` files the hand-kept exclude list had never been updated for.

**How to apply:** never add `exclude_paths` to `.reek.yml`, and if you find `.reek.yml` marked `S` in `git ls-files -v`, clear it (`git update-index --no-skip-worktree .reek.yml && git checkout -- .reek.yml`). Verified 2026-09-10: same reek config that reported 10 warnings over the four local-only files reports `0 total warnings` against the git-derived list. Related: [[project_worktree_db_isolation]], [[project-local-helpers-manual-worktree-sync]], [[project_worktree_coverage_seeding]]
