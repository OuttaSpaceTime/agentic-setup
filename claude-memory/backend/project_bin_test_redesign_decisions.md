---
name: project-bin-test-redesign-decisions
description: "Decisions from the 2026-10-27 transcript review of bin/test — once-per-handoff full run, method-level selection; BUILT and synced 2026-10-27"
metadata:
  node_type: memory
  type: project
  originSessionId: f07ce3ec-d7ca-4d43-b9ba-f4a85ffa6cca
  modified: 2026-10-29T19:29:43.800Z
---

Agreed with Felix on 2026-10-27 (walkthrough of steps 1-7 from a transcript analysis of 535 bin/test runs). BUILT 2026-10-27 (classes Arguments/TestMap/ChangedMethods/Selection/PatchGate inside bin/test, simplecov >= 1.3 guard) and copied with rule 800 to all 14 checkouts. Replay of 39 main commits: median 920 -> 212 tests, 43% fewer overall, 0 whole-suite fallbacks (was 6). Ignoring structural lines (end/class/private) measured as zero gain - rejected. 2026-10-28: .simplecov preloads gems (Rails pieces + Bundler.require(:default, :test)) under TRACK_TESTS so Coverage skips gem code: scoped bin/test 22.6s -> 17.0s, map and coverage unchanged; whole-suite runs gain nothing (bin/rails test without paths already loads gems first). Ruby PR #18406 (merged to master 2026-08-21, not in 4.0.6) caches branch-coverage templates and should remove most remaining tracking cost; re-measure the preload when upgrading Ruby. Known gap: pure-deletion hunks inside a method of a file that also has additions (9 of 40 commits).

- `--affected` stays, but runs **once per handoff**, not after every task (rule 800 step 3). It fell back to the full suite in 68/75 runs, mostly for legitimate triggers (schema, fixtures, test/support, openapi); an ignore list would have saved 1/20. It caught 2 real regressions the scoped run missed (fixture change in 1224, json_api_filter in 1324). Smarter triggering rejected: low payoff, weakens exactly those catches.
- Scoped selection becomes **method-level**: `git diff -U0 main` per named app/lib file → enclosing method (Prism) → same method by name in the map's stored `source` → `simplecov tests file:line` for every line of it. Query all method lines because `def`/`end` lines never have tests.
- Tests added on top: named test files + every `*_test.rb` changed vs main or untracked (`test/local` stays out via .git/info/exclude).
- **New methods/new files** get nothing from the map (option 1). Only if the whole selection is empty: whole-file fallback, or whole suite for a new file (rule b). Grepping callers rejected: 35 files for `include_mapping` via the generic Includable concern.

- **Test-file-only calls skip the gate** (print `gate skipped: no app/lib files named`). Today they gate the whole branch on partial coverage → false 0.00% reds (≥5 of 53 runs, e.g. 1321 subscriptions_controller.rb). Filling code files from git rejected: silently grows the run.

- **Test filters rejected loudly** (`-n`, `--name`, `file:line` → point to `bin/rails test`); today they're silently dropped and the whole file runs. **Non-`*_test.rb` paths under `test/` skipped with a note** (support files and fixtures crashed runs with NameError / InvalidTestError while agents followed rule 800).

- **Output noise: silenced at the source (2026-10-29), replacing option B.** bin/test no longer filters the test output (Felix chose plain `system` so dots stream live and in color). Instead `.simplecov`, under TRACK_TESTS, sets `SimpleCov.at_exit` to write only `JSONFormatter.new(silent: true)` (no Cobertura, no status lines; same owner check as simplecov's default hook) and sets `OpenapiFirst::Test.configuration.logger` to a null logger. test_helper.rb stays untouched; CI still gets coverage.xml.
- **Changed test files come from `SimpleCov::CLI::Affected::ChangedFiles`** (2026-10-29), not from the line diff's keys: a test file that only lost lines has no changed lines but must still run (HEAD~3 case: user_test.rb, −115 lines).
- **Gate = `bin/patch_coverage`** (2026-10-29): bin/test `exec`s the tracked CI gate with `--input`, so threshold and base live in one place.

**Why:** worked example `11491ab48 Fix exports N+1 query`: today ~16 test files, method-level 2 — exactly the 2 the map later recorded as executing `include_mapping`.

**How to apply:** since 2026-10-29 every worktree's `bin/test` and `.simplecov` are symlinks to main's (worktree.sh `_link_claude`), so edit them in main only ([[project_local_helpers_manual_worktree_sync]]).
