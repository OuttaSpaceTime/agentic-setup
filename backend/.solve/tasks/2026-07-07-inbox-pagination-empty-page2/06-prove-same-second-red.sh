#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
f=app/models/paginator/json_api_cursor.rb
trap 'git checkout -- "$f"' EXIT
# Break the fix: make cursor_value fall back to the truncating getter
sed -i 's/value.respond_to?(:iso8601) ? value.iso8601(6) : value/value/' "$f"
echo "=== running same-second test against UNFIXED cursor (expect FAIL) ==="
bin/rails test test/models/paginator_test.rb -i "/same/" || true
