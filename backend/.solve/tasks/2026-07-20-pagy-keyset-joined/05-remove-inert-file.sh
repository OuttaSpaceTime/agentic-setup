#!/usr/bin/env bash
# Drop the inert test; user wants only the three tests from the post.
set -euo pipefail
rm -f test/models/joined_sort_inert_test.rb
echo "removed joined_sort_inert_test.rb"
