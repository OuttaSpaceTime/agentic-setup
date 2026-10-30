#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
DRY_RUN=1 bin/rails runner .solve/scripts/seed_many_inbox_items.rb
