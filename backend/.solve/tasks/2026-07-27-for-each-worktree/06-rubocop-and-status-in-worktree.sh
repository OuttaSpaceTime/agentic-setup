#!/usr/bin/env bash
# bash .solve/tasks/2026-07-27-for-each-worktree/06-rubocop-and-status-in-worktree.sh
cd /home/felix/Code/Vilocify/worktrees/be-improve-organization-for-each
bundle exec rubocop -A app/models/organization.rb app/models/concerns/cleanup.rb app/models/task/membership_expiries_reminder.rb test/models/organization_test.rb test/models/task/membership_expiries_reminder_test.rb
npx editorconfig-checker
git diff --stat
