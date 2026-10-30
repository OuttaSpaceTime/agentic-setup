#!/usr/bin/env bash
# bash .solve/tasks/2026-07-27-for-each-worktree/04-run-cleanup-tests-in-worktree.sh
cd /home/felix/Code/Vilocify/worktrees/be-improve-organization-for-each
bin/rails test test/models/organization/cleanup_test.rb test/models/inbox/item/cleanup_test.rb test/models/user/cleanup_test.rb test/models/inbox/item/monitoring_list/notification/revision/cleanup_test.rb test/models/billing/archived_report/cleanup_test.rb test/models/inbox/event/cleanup_test.rb test/models/membership/cleanup_test.rb
