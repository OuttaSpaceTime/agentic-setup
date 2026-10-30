#!/usr/bin/env bash
set -euo pipefail
dir="$(dirname "$0")"
wl-copy < "$dir/issue.md"
echo "issue.md copied to clipboard ($(wc -l < "$dir/issue.md") lines)"
