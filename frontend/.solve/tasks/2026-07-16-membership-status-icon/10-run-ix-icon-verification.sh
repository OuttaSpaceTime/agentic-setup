#!/bin/bash
set -e
cd ~/Code/Misc/ix-icon-verify

pkill -f "ng serve --port 4400" 2>/dev/null || true
sleep 1
npx ng serve --port 4400 > /tmp/ix-icon-verify-serve.log 2>&1 &
disown

# wait for the dev server to be ready
for i in $(seq 1 40); do
  if grep -q "Local:   http://localhost:4400" /tmp/ix-icon-verify-serve.log 2>/dev/null; then break; fi
  sleep 1
done

node playwright-run.mjs

pkill -f "ng serve --port 4400" 2>/dev/null || true
