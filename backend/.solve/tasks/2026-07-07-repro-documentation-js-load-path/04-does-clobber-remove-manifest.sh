#!/usr/bin/env bash
set -uo pipefail
cd /home/felix/Code/Vilocify/vilocify-portal
echo "before clobber:"; ls -la public/backend-assets/.manifest.json 2>&1
bin/rails assets:clobber
echo "after clobber:"; ls -la public/backend-assets/.manifest.json 2>&1
