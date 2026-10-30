#!/bin/bash
# kills the scratch ng serve processes for the two repro apps (ports 4300 + 4400)
pkill -f "ng serve --port 4300" 2>/dev/null || true
pkill -f "ng serve --port 4400" 2>/dev/null || true
echo "killed scratch servers on 4300 and 4400 (if running)"
