#!/usr/bin/env bash
# bash .solve/tasks/2026-09-22-herdr-worktree/current.sh
# Probe: grep herdr's own bundled API schema for worktree event names.

herdr api schema --json > /tmp/herdr-schema.json
echo "schema bytes: $(wc -c < /tmp/herdr-schema.json)"

echo "=== worktree strings in schema ==="
jq -r '..|strings' /tmp/herdr-schema.json | grep -i worktree | sort -u

echo "=== dotted event-looking names ==="
jq -r '..|strings' /tmp/herdr-schema.json \
  | grep -E '^[a-z_]+\.[a-z_]+$' | sort -u | head -40
