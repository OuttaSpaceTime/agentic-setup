# Create worktree for 1135-admin-expiry-dedup

Move the in-progress AdminExpiry dedup changes onto their own branch/worktree so
`main` goes back to clean. Worktrees only carry committed files, so the 3 dirty
files get re-applied in the worktree afterwards; `main` stays dirty until Felix
reverts it.

Branch: `1135-admin-expiry-dedup`
Worktree: `~/Code/Vilocify/worktrees/be-1135-admin-expiry-dedup`

## Scripts (run in order)

- `01-create-worktree-and-copy-claude.sh` — git worktree add + deep-copy `.claude`.
  Verify: `ls ~/Code/Vilocify/worktrees/be-1135-admin-expiry-dedup/.claude/settings.json`
- `02-copy-config-and-npm-ci.sh` — copy gitignored env/console files, run `npm ci`.
- `03-isolate-databases.sh` — per-worktree dev+test DB names, `db:prepare`.
