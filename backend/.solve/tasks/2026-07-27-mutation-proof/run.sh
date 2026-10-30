#!/usr/bin/env bash
# bash .solve/tasks/2026-07-27-mutation-proof/run.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

restore() { git checkout -- app/models/membership/inbox.rb app/models/user.rb app/models/task/membership_expiries_reminder.rb; }
trap restore EXIT

probe() {
  local label="$1" file="$2" from="$3" to="$4" test_file="$5" test_name="$6"
  echo "=================================================================="
  echo "MUTATION: $label"
  echo "  $file: '$from' -> '$to'"
  perl -0pi -e "s/\Q$from\E/$to/" "$file"
  if ! git diff --quiet -- "$file"; then
    bin/rails test "$test_file" -n "$test_name"
    echo "EXIT_CODE=$? (expect non-zero == test protects the guard)"
  else
    echo "!! MUTATION DID NOT APPLY - pattern not found"
  fi
  restore
}

probe "inbox reminders skip expired orgs" \
  app/models/membership/inbox.rb \
  ".active_membership_in_active_org" ".active" \
  test/models/membership/inbox_test.rb \
  "/members of an expired organization/"

probe "announcements skip users only in expired orgs" \
  app/models/user.rb \
  ".active_membership_in_active_org" ".active" \
  test/jobs/send_out_announcement_job_test.rb \
  "/only membership is in an expired organization/"

probe "membership expiry reminder skips expired orgs" \
  app/models/task/membership_expiries_reminder.rb \
  "next if Current.organization.expired?" "" \
  test/models/task/membership_expiries_reminder_test.rb \
  "/does not send to members of an expired organization/"

probe "User scope excludes expired-org-only users" \
  app/models/user.rb \
  ".active_membership_in_active_org" ".active" \
  test/models/user_test.rb \
  "/excludes users whose only membership is in an expired organization/"

echo "=================================================================="
echo "final git status (must be clean for these 3 files):"
git status --porcelain app/models/membership/inbox.rb app/models/user.rb app/models/task/membership_expiries_reminder.rb
