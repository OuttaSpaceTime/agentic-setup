---
name: create-worktree
description: Create a git worktree for the vilocify-portal project in ~/Code/Vilocify/worktrees/vilocify-portal/ with all necessary config files copied from the main repo. Use this skill whenever the user wants to create a worktree, work in a worktree, set up a worktree, or mentions "worktree" in the context of this project. Also use when the user mentions wanting to work on a branch in isolation or wants a separate working directory for a branch.
---

# Create Worktree

Git worktrees only check out tracked files, so `.claude/`, gitignored dev config (`.env*`, console-helper initializers, the local-only migration scope guard in `config/initializers/migration_scope_guard.rb` + `test/local/`, the `bin/test` / `bin/quality` verify scripts + their `.simplecov`), and `node_modules` are left behind — which breaks Claude Code and the Rails dev/test environment. Those copied-in local helpers are untracked, and `bin/quality` lints only what `git ls-files --cached --others --exclude-standard` returns, so reek skips them everywhere without touching the shared `.reek.yml`. All the mechanics of bridging that gap live in **`scripts/worktree.sh`**. This file only covers the decisions you must make; the script does everything else and is idempotent (safe to re-run).

The worktree directory is always `~/Code/Vilocify/worktrees/vilocify-portal/<branch>` — the `<directory>/<repo>/<branch>` layout herdr uses for its `[worktrees] directory`, so worktrees made here and from the herdr sidebar share one folder. The Docker Postgres (`vilocifyportal-postgres-1` on `127.0.0.1:5433`) must be running — `docker compose up -d postgres` from any checkout if not.

## Commands

```
.claude/skills/create-worktree/scripts/worktree.sh create <branch> [start-point] [extra-file...]
.claude/skills/create-worktree/scripts/worktree.sh repair <worktree-path>
.claude/skills/create-worktree/scripts/worktree.sh remove <branch>
```

`create` symlinks `.claude/`, `CLAUDE.md`, `bin/test` and `.simplecov` to the main repo's, copies `bin/quality`, symlinks `.solve/scripts` back to the main repo, copies the gitignored dev config, runs `npm ci`, gives the worktree its own suffixed dev + test databases (the `config/database.yml` edit is hidden with `--skip-worktree`), loads fixtures into the new dev database, seeds `coverage/` from the main repo and starts a background whole-suite `bin/test` to rebuild the map from the branch's own code, copies any extra files, and prints a verification block. It exits non-zero with an `ERROR:` line if the worktree already exists or a new branch has no start-point, and prints a `WARN:` line for any extra file that didn't match.

## Creating a worktree

1. **Pick the start-point** (only needed for a new branch):
   - HEAD is already `main` → pass `main` silently.
   - HEAD is another branch → ask (AskUserQuestion) whether to branch from `main` or the current branch, and pass the answer.
   - The branch already exists → omit the start-point; the script checks it out.
   - The user named a start-point → pass it.
2. **Run** `scripts/worktree.sh create <branch> <start-point> [extra-files...]`.
   - If it errors `already exists`, ask the user whether to `remove` it or pick another name. **Never remove without confirmation.**
3. **Report** the worktree path, branch, the isolated dev + test DB names (from the verification block), and any `WARN:` lines.

## Repairing a worktree

A worktree missing files or with clobbered databases → `scripts/worktree.sh repair ~/Code/Vilocify/worktrees/vilocify-portal/<branch>`. It re-links `.claude/` + `CLAUDE.md`, re-copies config, re-runs `npm ci`, re-isolates the databases (reloading fixtures into dev), and re-verifies. To fix every worktree, loop over `~/Code/Vilocify/worktrees/vilocify-portal/*/` and run `repair` on each directory that contains a `.git` file.

## Removing a worktree

Destructive — **confirm with the user first.** `scripts/worktree.sh remove <branch>` drops this worktree's dev + test + parallel-worker databases (`DROP DATABASE ... WITH (FORCE)`, so lingering connections don't block it) and runs `git worktree remove`. It leaves the branch in place. If `git worktree remove` refuses because of untracked files, decide with the user whether to clean them or force removal.

## `test/local/` is reserved

`test/local/` is untracked, so each worktree has its own. `create`/`repair` copy exactly one file
into it — `migration_scope_guard_test.rb`, the test for the untracked scope guard. Everything else
there is written by whoever works in that worktree, and only two kinds of file may be: a migration
test, and a test whose subject is itself an untracked local helper. See
`.claude/rules/320-migration-tests.md`. A perf probe, a security audit or any other test of
committed code parked there is invisible to CI and to every colleague — it belongs in the committed
test tree, or in a scratchpad script.

`.claude/` and `CLAUDE.md` are untracked too, so each worktree gets a symlink to the main repo's
copy: a rule, hook or settings change in the main repo reaches every worktree at once. Edit them
in the main repo only.

## The local-only verify scripts

`bin/test`, `bin/quality` and `.simplecov` are deliberately **untracked** — listed in
`.git/info/exclude`, which lives in the common git dir and so hides them in every worktree at once.
Never `git add -f` them. `create`/`repair` symlink `bin/test` and `.simplecov` to the main repo's, so
a change there reaches every worktree at once (`bin/test` aborts on a branch older than simplecov 1.3),
and copy `bin/quality` with `cp -p` so it keeps its executable bit.

They stay untracked with no `--skip-worktree` companion because nothing tracked has to change for
them to work: `track_tests` is switched on from the untracked `.simplecov`, which SimpleCov loads
at `require` time, so `test/test_helper.rb` is left pristine.

`bin/test` needs `coverage/map/coverage.json` — the index that resolves an app file to the tests
covering it. Without it, `bin/test app/models/foo.rb` warns and runs the whole suite to rebuild it.
`create`/`repair` therefore `cp -rp` the main repo's `coverage/` into the worktree — its keys are
repo-relative, so a branch a few commits off `main` carries over — and then launch `./bin/test`
with no arguments in the background, whose whole-suite run replaces the map with one recorded from
this branch. The rebuild is what makes `bin/test <file>` resolve tests: only a `TRACK_TESTS` run
writes per-test attributions, so a `coverage/map/coverage.json` left behind by a plain
`bin/rails test` copies over but answers `no recorded test covers …` for everything. Check the seed
with `bundle exec simplecov tests app/models/monitoring_list.rb --input coverage/map/coverage.json`.
Watch the rebuild with `tail -f <worktree>/tmp/test-map-rebuild.log`, and don't run `bin/test`
yourself until it finishes — both runs write the same `coverage/`. If the main repo has no
`coverage/map/coverage.json` at all, the script prints a `WARN:` line and skips both steps.

Both scripts need a branch rebased onto current `main` and refuse to run otherwise, with one line
saying so rather than a backtrace:

- `bin/test` needs simplecov >= 1.2 (its `tests`/`patch`/`affected` CLI and `track_tests`)
- `bin/quality` needs `bin/reek` and the `flay:check` / `flog:check` rake tasks, added in
  `5b626826c`

Do **not** copy those prerequisites into an old worktree — they are tracked files, and copies would
show up as phantom changes and collide on rebase. Rebase the branch instead. `.simplecov` guards its
call with `respond_to?(:track_tests)`, so it stays silent on a simplecov 0.22 branch.

## Caveat

`config/database.yml` is `--skip-worktree`, so git can't merge an upstream change to it into the worktree. If it changes on the branch: `git update-index --no-skip-worktree config/database.yml`, reconcile, then run `repair`. `repair` restores it from the index before re-applying its edit, so uncommitted hand-edits are discarded — reconcile first. This happened in `f0c8bb865` (2026-09-21) — every worktree created before it still holds the pre-change file, and picks up the new one only on rebase + `repair`.

That commit parameterized the tracked test database name as `vilocify_portal_test_<%= Rails.root.basename … %>`, and `_isolate_db` overwrites it anyway, because for a long branch directory the upstream scheme breaks: `vilocify_portal_test_be-1279-migrate-all-database-columns-to-prevent-null-values` is 80 characters, PostgreSQL truncates every identifier to 63 with only a `NOTICE`, and the `-0`…`-19` parallel-worker suffix is what gets cut — so all 20 workers land in one database. The `<20-char slug>_<6-char md5>` suffix exists to stay under that limit. The sed matches the whole line after `vilocify_portal_dev` / `vilocify_portal_test`, so it handles both the old bare name and the new ERB one and a worktree gets the same DB names either way.

`.reek.yml` is deliberately **not** touched — no `exclude_paths`, no `--skip-worktree`. Local-only helpers stay out of reek because `bin/quality` passes it a git-derived file list instead of the `app lib config test` directories that tracked `bin/reek` walks. So run `bin/quality`, not `bin/reek`, locally; and a `reek --todo` regeneration needs no repair afterwards.
