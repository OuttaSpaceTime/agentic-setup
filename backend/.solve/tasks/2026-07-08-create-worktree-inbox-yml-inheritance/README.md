# Create worktree: inbox-items-yml-inheritance

Runs the /create-worktree skill for branch `inbox-items-yml-inheritance`
(dir `~/Code/Vilocify/worktrees/be-inbox-items-yml-inheritance`), based on `main`.
Purpose of the branch: improve the inbox items YAML schema to support inheritance.

Each script is self-contained (no args). Run bare: `bash <script>`.

- `01-create-worktree.sh` — `git worktree add -b` new branch from main.
- `02-copy-claude-and-config.sh` — deep-copy `.claude/`, copy gitignored env/console files.
- `03-npm-ci.sh` — `npm ci` in the worktree (openapi-explorer asset + redocly binary).
- `04-isolate-databases.sh` — unique dev+test DB names, `--skip-worktree`, `db:prepare`.
- `05-verify.sh` — read-only checks: git status clean, .claude present, DB names suffixed.
