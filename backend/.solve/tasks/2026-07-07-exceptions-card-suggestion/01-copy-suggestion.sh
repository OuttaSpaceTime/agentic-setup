#!/bin/sh
src="/tmp/claude-1000/-home-felix-Code-Vilocify-vilocify-portal/008b7e75-f23a-49ee-881d-6267bd729edb/scratchpad/exceptions-testing-suggestion.md"
grep -c '—' "$src" >/dev/null && test "$(grep -c '—' "$src")" = "0" || echo "WARN: em dashes present"
wl-copy < "$src" && echo "copied $(wc -c < "$src") bytes"
