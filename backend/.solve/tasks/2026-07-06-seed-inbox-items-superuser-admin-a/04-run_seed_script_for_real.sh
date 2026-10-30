#!/usr/bin/env bash
set -euo pipefail
bin/rails runner script/seed_inbox_items_for_superuser_admin_in_org_a
