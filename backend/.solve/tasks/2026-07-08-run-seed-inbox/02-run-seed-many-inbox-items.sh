#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
bin/rails runner .solve/scripts/seed_many_inbox_items.rb
