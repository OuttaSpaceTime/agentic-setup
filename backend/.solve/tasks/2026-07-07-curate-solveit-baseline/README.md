# Curate SolveIt Bash baseline

Reduce the repo's `permissions.allow` Bash entries to the barebones validation
baseline (rules 800 + 801, `bin/local_ci`) and drop the noise.

## 01-apply-baseline.sh

- Adds the 7 baseline globs to committed `.claude/settings.json` (test, rubocop,
  editorconfig, rake, openapi-diff, oasdiff, db:migrate).
- Removes **every** `Bash(...)` entry from `.claude/settings.local.json`
  (baseline moves to the shared file; everything else is dropped).
- `Read(//tmp/**)` and non-permission keys are left untouched.

Run:  `bash .solve/tasks/2026-07-07-curate-solveit-baseline/01-apply-baseline.sh`
Verify:  `solve-allow list`  → shows only the 7 baseline globs.
