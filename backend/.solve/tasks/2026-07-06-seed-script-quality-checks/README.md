# Quality checks for seed_inbox_items_for_superuser_admin_in_org_a

Runs the project's required quality gates (per
`.claude/rules/800-quality-tools.md`) against the new
`script/seed_inbox_items_for_superuser_admin_in_org_a`.

## Scripts

- `01-run_quality_tools.sh` — runs `bundle exec rubocop -A` and
  `npx editorconfig-checker` against the script, from the repo root.
- `02-make_script_executable.sh` — `chmod +x` the seed script, to fix
  rubocop's `Lint/ScriptPermission` offense (not autocorrectable).
