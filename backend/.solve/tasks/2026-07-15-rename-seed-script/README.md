# Rename seed-script skill → script-seed, split out script-performance

Reorganize the `.claude/skills/seed-script` skill:
1. Rename dir `seed-script` → `script-seed` (this task, `01-...`).
2. (later) Fix `name:` frontmatter + trim the performance section out of it.
3. (later) Create a new `script-performance` skill from the "Measuring against
   seeded data" section.

## 01-rename-skill-dir.sh
Plain `git`-free `mv` of the skill directory. Run: `bash .solve/tasks/2026-07-15-rename-seed-script/01-rename-skill-dir.sh`
Verify: `ls .claude/skills/` shows `script-seed`, no `seed-script`.
