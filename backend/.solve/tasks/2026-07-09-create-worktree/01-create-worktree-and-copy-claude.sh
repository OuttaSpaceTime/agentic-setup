#!/usr/bin/env bash
set -euo pipefail
MAIN="$HOME/Code/Vilocify/vilocify-portal"
WT="$HOME/Code/Vilocify/worktrees/be-1135-admin-expiry-dedup"
mkdir -p "$HOME/Code/Vilocify/worktrees"
cd "$MAIN"
git worktree add -b 1135-admin-expiry-dedup "$WT" main
rm -rf "$WT/.claude"
cp -r "$MAIN/.claude" "$WT/.claude"
rm -rf "$WT/.claude/worktrees"
echo "worktree ready: $WT"
