---
name: project-create-worktree-skill
description: create-worktree skill for vilocify-frontend — spins up worktrees that actually build/test
metadata: 
  node_type: memory
  type: project
  originSessionId: ec20a9ae-7aa0-4e80-8882-09eea8387647
  modified: 2026-10-06T08:18:03.428Z
---

Project-local skill at `.claude/skills/create-worktree/` (gitignored, local-only) in vilocify-frontend, created 2026-06-23.

Drives `scripts/create-worktree.sh <branch...>` which, per branch: creates a worktree under `../worktrees/vilocify-frontend/<name>` (a `worktrees/` dir SIBLING to the repo; backend uses `../worktrees/vilocify-portal/<name>`) on a new branch off `main`, symlinks `node_modules` (absolute) to the main repo's, symlinks `.claude/` to the main repo's (since 2026-10-28, was a copy) so rules/scripts/skills are present and never lag, copies `.editorconfig-checker.json`, then runs `ng lint` + `ng test`.

**NEVER create worktrees under `.claude/` — Felix corrected this hard (2026-07-13).** They belong in the sibling `/home/felix/Code/Vilocify/worktrees/`. The authoritative skill copy (main repo `.claude/skills/create-worktree/`) is already correct.

**Stale per-worktree copies (fixed 2026-10-28):** `.claude/` used to be copied, so each worktree held a snapshot that lagged main. A stale create-worktree script once built under `.claude/worktrees/`, and a stale rule 800 kept agents running editorconfig after its removal. All worktrees now symlink `.claude/`; old copies are in `~/Code/Vilocify/.worktree-claude-copies-2026-10-28/`. To relocate a misplaced worktree: `git worktree move <old> <new>` (absolute node_modules symlink survives).

**Why the symlink + copy matter:** a bare `git worktree add` omits gitignored files. Two things then break — (1) imports anchored to tsconfig `baseUrl` like `import { add } from 'node_modules/date-fns/add'` (in `api-token-card.component.ts`) can't resolve without `node_modules/` at the worktree root; (2) `.claude/` rules and `scripts/dev-server.sh` are missing. Env: `BASE=<ref>`, `VERIFY=0` to skip tests.

**herdr wiring (2026-10-06):** worktrees now live at `../worktrees/vilocify-frontend/<branch>` (herdr's `<worktrees>/<repo>/<branch>` layout, no `fe-` prefix). herdr plugin `~/Code/Vilocify/herdr-vilocify/bin/worktree_created.sh` (not a git repo) calls `create-worktree.sh repair <path>` when the new worktree has `angular.json`; backend branch keys on `Gemfile`. Before this, herdr-created frontend worktrees got no setup at all.

Known caveat: `editorconfig-checker` reports ~180 pre-existing errors in generated `src/readme-oss.html` — not a failure, and the script deliberately doesn't run it. Related: [[project_autoresearch_skill]].
