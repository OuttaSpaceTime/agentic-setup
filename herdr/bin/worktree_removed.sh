#!/usr/bin/env sh
set -eu

MAIN="$HOME/Code/Vilocify/vilocify-portal"
PG=vilocifyportal-postgres-1
WT=$(printf '%s' "$HERDR_PLUGIN_EVENT_JSON" | jq -r '.data.worktree.path')

case "$WT" in
  "$HOME"/Code/Vilocify/worktrees/*) ;;
  *) exit 0 ;;
esac

slug=$(basename "${WT%/}" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9]/_/g' | cut -c1-20)
suffix="${slug}_$(printf '%s' "${WT%/}" | md5sum | cut -c1-6)"

echo "worktree removed: $WT"
echo "suffix: $suffix"
echo "databases that would be dropped:"
docker exec "$PG" psql -U postgres -tAc \
  "SELECT datname FROM pg_database WHERE datname LIKE 'vilocify_portal_%${suffix}%'"
