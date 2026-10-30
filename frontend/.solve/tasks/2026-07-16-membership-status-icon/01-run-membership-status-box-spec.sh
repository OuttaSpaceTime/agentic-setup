#!/bin/bash
set -e
cd /home/felix/Code/Vilocify/vilocify-frontend
npx ng test \
  --include='src/app/features/memberships/components/membership-status-box/membership-status-box.component.spec.ts' \
  --watch=false --browsers=ChromeHeadlessNoSandbox
