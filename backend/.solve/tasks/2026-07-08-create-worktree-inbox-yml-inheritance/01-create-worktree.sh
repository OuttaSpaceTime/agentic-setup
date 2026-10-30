#!/usr/bin/env bash
set -euo pipefail
main=~/Code/Vilocify/vilocify-portal
wt=~/Code/Vilocify/worktrees/be-inbox-items-yml-inheritance
cd "$main"
git worktree add -b inbox-items-yml-inheritance "$wt" main
git -C "$wt" status
