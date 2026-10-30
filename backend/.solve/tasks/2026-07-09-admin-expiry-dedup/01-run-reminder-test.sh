#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
bin/rails test test/models/task/membership_expiries_reminder_test.rb
