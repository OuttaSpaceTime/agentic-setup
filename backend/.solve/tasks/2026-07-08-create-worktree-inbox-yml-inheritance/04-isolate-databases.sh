#!/usr/bin/env bash
set -euo pipefail
cd ~/Code/Vilocify/worktrees/be-inbox-items-yml-inheritance
wt_path="$(pwd)"
slug="$(basename "$wt_path" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9]/_/g' | cut -c1-20)"
suffix="${slug}_$(printf '%s' "$wt_path" | md5sum | cut -c1-6)"
git update-index --no-skip-worktree config/database.yml 2>/dev/null || true
git checkout -- config/database.yml
sed -i -E \
  -e "s/^( *database: vilocify_portal_dev)\$/\1_${suffix}/" \
  -e "s/^( *database: vilocify_portal_test)\$/\1_${suffix}/" \
  config/database.yml
git update-index --skip-worktree config/database.yml
bin/rails db:prepare
