# Create worktree for issue #1146

Branch: `1146-paused-monitoring-lists-should-not-send-out-security-notifications`
Worktree dir: `~/Code/Vilocify/worktrees/be-1146-...`

Follows the create-worktree skill. HEAD is `main`, so branch from `main`.

## Scripts
- `01-create-worktree.sh` — `git worktree add -b <branch>` from main. Verify: `git worktree list` shows the new path.
- `02-copy-config.sh` — deep-copy `.claude/`, copy gitignored env + console-helper files. Verify: `.claude/settings.json` and `.env.development.local` exist in worktree.
- `03-npm-and-db.sh` — `npm ci`, isolate `config/database.yml` DB names, `db:prepare`. Verify: `redocly --version` prints a number; grep shows suffixed DB names.
