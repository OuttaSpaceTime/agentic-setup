#!/usr/bin/env bash
set -euo pipefail
main=~/Code/Vilocify/vilocify-portal
wt=~/Code/Vilocify/worktrees/be-inbox-items-yml-inheritance
cd "$wt"
echo "== git status (database.yml must be hidden) =="; git status --short
echo "== .claude present =="; ls .claude/settings.json .claude/rules/ >/dev/null && echo OK
echo "== rule counts =="; echo "main: $(ls "$main/.claude/rules/" | wc -l)  wt: $(ls .claude/rules/ | wc -l)"
echo "== redocly =="; npx --no-install redocly --version 2>&1 | tail -1
echo "== DB names =="; grep -E 'database: vilocify_portal_(dev|test)' config/database.yml
