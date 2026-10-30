---
name: project_worktree_coverage_seeding
description: "New worktrees get coverage/ copied from main plus a background whole-suite bin/test, because only a TRACK_TESTS run writes the per-test map"
metadata:
  type: project
---

`create`/`repair` in the create-worktree skill `cp -rp` the main repo's `coverage/` into the worktree and then launch `./bin/test` (no args) with nohup in the background, logging to `<worktree>/tmp/test-map-rebuild.log`.

**Why:** `bin/test <file>` resolves a file to its tests through `coverage/map/coverage.json`, which git never carries into a worktree (`/coverage` is gitignored), so the first scoped run would rebuild it by running the whole suite. The copy alone is not enough: only a run with `TRACK_TESTS=1` (i.e. `bin/test` itself, via the untracked `.simplecov`) writes per-test attributions — a map left behind by a plain `bin/rails test` copies over fine but answers `no recorded test covers …` for every path. That was exactly the state of main's map on 2026-09-10 (858 KB, no attributions); the background whole-suite rebuild produced a 2.4 MB map that resolved `app/models/monitoring_list.rb` to real test locations.

**How to apply:** probe a map with `bundle exec simplecov tests app/models/monitoring_list.rb --input coverage/map/coverage.json`. Don't run `bin/test` while the background rebuild is going — both write the same `coverage/`. Branches predating simplecov 1.2 (`ruby 4.0.1` in `.ruby-version`) just log `bin/test`'s "rebase onto main" abort. Related: [[project_worktree_db_isolation]], [[project_reek_local_file_exclusion]]
