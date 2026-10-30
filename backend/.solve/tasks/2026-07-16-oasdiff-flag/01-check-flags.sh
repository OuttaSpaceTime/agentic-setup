#!/usr/bin/env bash
set -uo pipefail
echo "=== version ==="
oasdiff --version
echo "=== breaking --help (upgrade-related) ==="
oasdiff breaking --help 2>&1 | grep -i "upgrade\|flatten" || echo "(no upgrade flag found)"
