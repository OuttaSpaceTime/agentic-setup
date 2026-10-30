#!/usr/bin/env bash
# bash .solve/tasks/2026-07-27-mutation-proof/seed_sweep.sh
cd "$(git rev-parse --show-toplevel)"

FILES="test/models/billing/consumption_period_test.rb test/jobs/billing/send_consumption_reports_job_test.rb"

for SEED in 47740 1 2 3 42 999 12345 54321; do
  OUT=$(bin/rails test $FILES --seed "$SEED" 2>&1)
  echo "seed=$SEED  $(echo "$OUT" | grep -E '^[0-9]+ runs')"
done
