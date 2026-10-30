#!/usr/bin/env bash
# bash .solve/tasks/2026-07-27-for-each-worktree/03-run-for-each-caller-tests-in-worktree.sh
cd /home/felix/Code/Vilocify/worktrees/be-improve-organization-for-each
bundle exec rubocop -A app/models/organization.rb test/models/organization_test.rb
bin/rails test test/models/organization_test.rb test/jobs/component_pull_job_test.rb test/models/task/membership_expiries_reminder_test.rb test/models/component_test.rb
