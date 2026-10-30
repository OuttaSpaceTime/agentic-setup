#!/usr/bin/env bash
set -euo pipefail
main=~/Code/Vilocify/vilocify-portal
wt=~/Code/Vilocify/worktrees/be-1146-paused-monitoring-lists-should-not-send-out-security-notifications
branch=1146-paused-monitoring-lists-should-not-send-out-security-notifications
cd "$main"
git worktree add -b "$branch" "$wt" main
git worktree list
