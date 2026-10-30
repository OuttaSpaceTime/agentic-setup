#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
bin/rails test test/jobs/notification_event_process_job_test.rb
