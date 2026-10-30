#!/usr/bin/env bash
# bash .solve/tasks/2026-07-27-for-each-worktree/07-verify-rename-in-worktree.sh
cd /home/felix/Code/Vilocify/worktrees/be-improve-organization-for-each
echo "--- leftover for_each ---"; grep -rn "for_each" app test lib || echo none
bundle exec rubocop -A app test
bin/rails test test/models/organization_test.rb test/models/task/membership_expiries_reminder_test.rb test/jobs/component_pull_job_test.rb test/models/component_test.rb test/models/organization/cleanup_test.rb test/models/membership/cleanup_test.rb test/models/user/cleanup_test.rb test/models/inbox/item/cleanup_test.rb test/models/inbox/event/cleanup_test.rb test/models/billing/archived_report/cleanup_test.rb
