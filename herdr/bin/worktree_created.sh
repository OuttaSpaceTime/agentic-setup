#!/usr/bin/env sh
set -eu

MAIN="$HOME/Code/Vilocify/vilocify-portal"
WT=$(printf '%s' "$HERDR_PLUGIN_EVENT_JSON" | jq -r '.data.worktree.path')

if [ -f "$WT/angular.json" ]; then
  cd "$WT"
  exec "$HOME/Code/Vilocify/vilocify-frontend/.claude/skills/create-worktree/scripts/create-worktree.sh" repair "$WT"
fi

[ -f "$WT/Gemfile" ] || exit 0

(cd "$MAIN" && docker compose up -d postgres)
"$MAIN/.claude/skills/create-worktree/scripts/worktree.sh" repair "$WT"
