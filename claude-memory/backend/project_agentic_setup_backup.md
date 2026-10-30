---
name: project-agentic-setup-backup
description: "~/Code/Misc/agentic-setup snapshots everything .git/info/exclude hides in portal+frontend, plus memory, herdr plugin, vil-db-reset; restore.sh puts it back"
metadata:
  node_type: memory
  type: project
  originSessionId: 9ba5bc66-5b82-43af-b5e6-e4e553832016
  modified: 2026-10-30T05:54:29.536Z
---

Since 2026-10-30, `~/Code/Misc/agentic-setup` is the backup of the untracked agent setup: `backend/` and `frontend/` mirror every path `.git/info/exclude` hides (plus `git-info-exclude`; nested `.solve/tasks/*/.git` scratch repos left out — some carry the work email), `claude-memory/`, `herdr/`, `bin/vil-db-reset`, and `shell/aliases.zsh` (all shell aliases/functions, sourced live from `~/.zshrc`). `global/` is a reference snapshot only — chezmoi (`~/Code/Misc/master-terminal/home`) owns those files. Folder names deliberately avoid "vilocify".

**Why:** none of this is in any git remote; the user wants to reproduce the setup on a fresh machine.

**How to apply:** after changing rules, skills, hooks, `bin/test`, memory or aliases, re-sync the snapshot (rsync each excluded path) and commit there. Personal GitHub repos are scrubbed of the employer name and work email (the `backup/pre-resync/*` branches in ~/Code/Misc hold the unscrubbed originals and must never be pushed); scan before every push. Secrets never go in: `VILOCIFY_API_TOKEN` lives in unmanaged `~/.zshrc.local`, `.env*` and `dump.sql` are excluded. Related: [[project-local-helpers-manual-worktree-sync]], [[project-herdr-worktree-layout]].
