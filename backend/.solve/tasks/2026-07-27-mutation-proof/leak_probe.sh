#!/usr/bin/env bash
# bash .solve/tasks/2026-07-27-mutation-proof/leak_probe.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

JOB_TEST=test/jobs/billing/send_consumption_reports_job_test.rb
SEED=47740
trap 'git checkout -- "$JOB_TEST"' EXIT

echo "### A: job test file ALONE, with my test present, seed $SEED"
bin/rails test "$JOB_TEST" --seed "$SEED"
echo "EXIT=$?"

echo
echo "### B: both files, WITHOUT my test (latent?), seed $SEED"
perl -0pi -e "s/\n  test\('sends the report to an admin of an expired organization'\).*?\n  end\n//s" "$JOB_TEST"
grep -c "admin of an expired organization" "$JOB_TEST" || echo "(my test removed)"
bin/rails test test/models/billing/consumption_period_test.rb "$JOB_TEST" --seed "$SEED"
echo "EXIT=$?"
