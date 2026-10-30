#!/usr/bin/env bash
set -euo pipefail
# Drop every per-worktree DB with no live worktree. Verify with 02-dry-run first.

cd /home/felix/Code/Vilocify/vilocify-portal

live=$(git worktree list | awk 'NR>1{print $1}' | while read -r wt; do
  slug=$(basename "$wt" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9]/_/g' | cut -c1-20)
  printf '%s_%s\n' "$slug" "$(printf '%s' "$wt" | md5sum | cut -c1-6)"
done)

orphans=$(PGPASSWORD=password psql -h localhost -p 5433 -U postgres -Atc \
  "select datname from pg_database where datname ~ '^vilocify_portal_(dev|test)_.+_[0-9a-f]{6}(_[0-9]+)?\$' order by datname" \
  | while read -r db; do
      base=$(printf '%s' "$db" | sed -E 's/^vilocify_portal_(dev|test)_//; s/^(.+_[0-9a-f]{6})(_[0-9]+)?$/\1/')
      grep -qxF "$base" <<< "$live" || echo "$db"
    done)

echo "Dropping $(grep -c . <<< "$orphans") orphan databases..."
while read -r db; do
  [[ -z "$db" ]] && continue
  echo "  drop $db"
  PGPASSWORD=password psql -h localhost -p 5433 -U postgres -c \
    "drop database if exists \"$db\" with (force)" >/dev/null
done <<< "$orphans"
echo "Done."
