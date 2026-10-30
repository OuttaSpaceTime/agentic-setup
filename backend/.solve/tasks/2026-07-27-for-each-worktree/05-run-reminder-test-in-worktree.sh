#!/usr/bin/env bash
# bash .solve/tasks/2026-07-27-for-each-worktree/05-run-reminder-test-in-worktree.sh
cd /home/felix/Code/Vilocify/worktrees/be-improve-organization-for-each
bin/rails test test/models/task/membership_expiries_reminder_test.rb
