#!/usr/bin/env bash
# bash .solve/tasks/2026-07-27-mailer-subject-flake/01-run-suite-10x-random-seeds.sh
# Full suite, 10 random seeds. Full output kept per run; only the tally is printed.
set -u
out=.solve/tasks/2026-07-27-mailer-subject-flake/logs
mkdir -p "$out"
for i in $(seq 1 10); do
  seed=$((RANDOM))
  log="$out/run-$i-seed-$seed.log"
  bin/rails test --seed "$seed" >"$log" 2>&1
  printf '%s seed=%s :: %s\n' "run-$i" "$seed" "$(grep -E '^[0-9]+ runs,' "$log")"
  grep -E '^(Failure|Error):' -A2 "$log" || true
done
echo "full logs: $out"
