#!/usr/bin/env bash
# bash .solve/tasks/2026-09-22-herdr-worktree/current.sh
# Probe: does herdr 0.9.1 expose a worktree removal event?

echo "=== herdr api --help ==="
herdr api --help 2>&1 | head -30

echo "=== herdr api events ==="
herdr api events 2>&1 | head -40

echo "=== herdr plugin --help ==="
herdr plugin --help 2>&1 | head -20
