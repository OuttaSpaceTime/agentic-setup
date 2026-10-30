#!/usr/bin/env bash
set -euo pipefail
MAIN="$HOME/Code/Vilocify/vilocify-portal"
WT="$HOME/Code/Vilocify/worktrees/be-1135-admin-expiry-dedup"
for f in .env .env.development.local .env.test.local \
         config/initializers/fixture_console_helpers.rb \
         config/initializers/unscope_console_helper.rb; do
  [ -f "$MAIN/$f" ] && cp "$MAIN/$f" "$WT/$f"
done
cd "$WT"
npm ci
echo "config copied, npm ci done"
