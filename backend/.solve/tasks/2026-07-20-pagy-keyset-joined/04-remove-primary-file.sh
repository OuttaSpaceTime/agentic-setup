#!/usr/bin/env bash
# Remove the 4th test file; its cves-primary test was merged into
# pagy_keyset_joined_cursor_test.rb as a second test method.
set -euo pipefail
rm -f test/models/pagy_keyset_joined_cursor_primary_test.rb
echo "removed pagy_keyset_joined_cursor_primary_test.rb"
