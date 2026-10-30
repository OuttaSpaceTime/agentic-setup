#!/usr/bin/env bash
set -euo pipefail
# Dry run: print which per-worktree DBs the gwr sweep would drop. No drops.

cd /home/felix/Code/Vilocify/vilocify-portal

# Live worktree DB suffixes (slug_hash6), recomputed from remaining worktrees.
live_suffixes=$(git worktree list | awk 'NR>1{print $1}' | while read -r wt; do
  slug=$(basename "$wt" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9]/_/g' | cut -c1-20)
  printf '%s_%s\n' "$slug" "$(printf '%s' "$wt" | md5sum | cut -c1-6)"
done)

echo "=== live suffixes ==="
echo "$live_suffixes"

echo
echo "=== orphan DBs that would be dropped ==="
PGPASSWORD=password psql -h localhost -p 5433 -U postgres -Atc \
  "select datname from pg_database where datname ~ '^vilocify_portal_(dev|test)_.+_[0-9a-f]{6}(_[0-9]+)?\$' order by datname" \
  | while read -r db; do
      base=$(printf '%s' "$db" | sed -E 's/^vilocify_portal_(dev|test)_//; s/^(.+_[0-9a-f]{6})(_[0-9]+)?$/\1/')
      grep -qxF "$base" <<< "$live_suffixes" || echo "$db"
    done
