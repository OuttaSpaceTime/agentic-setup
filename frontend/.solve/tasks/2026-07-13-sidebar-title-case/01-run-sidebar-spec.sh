#!/usr/bin/env bash
set -euo pipefail
cd /home/felix/Code/Vilocify/vilocify-frontend
npx ng test \
  --include='src/app/core/layout/components/sidebar/sidebar.component.spec.ts' \
  --watch=false --browsers=ChromeHeadlessNoSandbox
