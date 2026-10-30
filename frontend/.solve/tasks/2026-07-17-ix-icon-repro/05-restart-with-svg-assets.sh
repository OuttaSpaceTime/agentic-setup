#!/bin/bash
set -e
cd ~/Code/Misc/ix-icon-lazy-route-repro

pkill -f "ng serve --port 4300" 2>/dev/null || true
sleep 1

npx ng serve --port 4300 > /tmp/ix-icon-lazy-route-repro-serve.log 2>&1 &
disown
sleep 8
tail -n 30 /tmp/ix-icon-lazy-route-repro-serve.log
