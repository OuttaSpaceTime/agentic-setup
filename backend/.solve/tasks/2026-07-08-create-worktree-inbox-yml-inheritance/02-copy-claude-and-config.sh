#!/usr/bin/env bash
set -euo pipefail
main=~/Code/Vilocify/vilocify-portal
wt=~/Code/Vilocify/worktrees/be-inbox-items-yml-inheritance
rm -rf "$wt/.claude"
cp -r "$main/.claude" "$wt/.claude"
rm -rf "$wt/.claude/worktrees"
for f in .env .env.development.local .env.test.local \
         config/initializers/fixture_console_helpers.rb \
         config/initializers/unscope_console_helper.rb; do
  [ -f "$main/$f" ] && cp "$main/$f" "$wt/$f" && echo "copied $f" || echo "skip  $f"
done
