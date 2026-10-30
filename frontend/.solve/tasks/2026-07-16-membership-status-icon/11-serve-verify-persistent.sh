#!/bin/bash
# starts a persistent dev server for the verify app (no playwright, no auto-kill)
set -e
cd ~/Code/Misc/ix-icon-verify
pkill -f "ng serve --port 4400" 2>/dev/null || true
sleep 1
npx ng serve --port 4400
