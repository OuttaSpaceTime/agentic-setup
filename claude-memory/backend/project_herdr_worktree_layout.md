---
name: project-herdr-worktree-layout
description: "Portal worktrees live at ~/Code/Vilocify/worktrees/vilocify-portal/<branch> (herdr's fixed <dir>/<repo>/<branch-slug> layout), not be-<branch>"
metadata:
  node_type: memory
  type: project
  originSessionId: 6dc29a0e-aa12-46bd-8a63-8781fb620029
  modified: 2026-09-29T12:38:17.716Z
---

Since 2026-09-29 the create-worktree skill creates `~/Code/Vilocify/worktrees/vilocify-portal/<branch>`, matching herdr's `[worktrees] directory = "~/Code/Vilocify/worktrees"` (herdr has no path-template option; layout is fixed at `<directory>/<repo>/<branch-slug>`). Existing `be-*` worktrees were moved with `git worktree move` and their suffixed DBs renamed (`ALTER DATABASE … RENAME`), keeping data.

herdr's sidebar shows only *open* workspaces; `herdr worktree list` sees every git worktree. Open one with `herdr worktree open --workspace w1 --path <wt> --no-focus` — verified it does not fire the plugin's `worktree.created` hook (so no fixture reload).

**Why:** the user wants herdr and the skill to share one folder so herdr groups every worktree.
**How to apply:** new or repaired portal worktrees go under `worktrees/vilocify-portal/`; the frontend skill still uses `worktrees/fe-<branch>` unless it was changed too. See [[project-worktree-db-isolation]].
