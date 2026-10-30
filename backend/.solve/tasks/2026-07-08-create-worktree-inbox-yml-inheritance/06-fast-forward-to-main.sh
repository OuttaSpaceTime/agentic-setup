#!/usr/bin/env bash
set -euo pipefail
wt=~/Code/Vilocify/worktrees/be-inbox-items-yml-inheritance
cd "$wt"
git merge --ff-only main
git log --oneline -1
