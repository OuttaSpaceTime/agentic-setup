#!/usr/bin/env bash
set -euo pipefail

echo "=== databases in shared postgres (:5433) ==="
PGPASSWORD=password psql -h localhost -p 5433 -U postgres -Atc \
  "select datname from pg_database where datname like 'vilocify_portal%' order by datname"

echo
echo "=== live git worktrees ==="
git -C /home/felix/Code/Vilocify/vilocify-portal worktree list
