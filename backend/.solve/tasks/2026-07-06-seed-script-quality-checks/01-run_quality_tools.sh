#!/usr/bin/env bash
set -euo pipefail
bundle exec rubocop -A script/seed_inbox_items_for_superuser_admin_in_org_a
npx editorconfig-checker script/seed_inbox_items_for_superuser_admin_in_org_a
