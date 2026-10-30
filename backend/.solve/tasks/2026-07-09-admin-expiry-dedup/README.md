# AdminExpiry reminder dedup (work item 1135)

Bug: `Task::MembershipExpiriesReminder.send_admin_summary_mails!` re-creates an
identical AdminExpiry inbox item every Monday for unchanged expired memberships.

Decision (with Karim): always include expiring memberships weekly; include an
expired membership only **once**, tracked via `expiry_notified_at` snapshot on
the membership.

## Scripts

- `01-run-reminder-test.sh` — runs the reminder task test file.
  Run: `bash .solve/tasks/2026-07-09-admin-expiry-dedup/01-run-reminder-test.sh`
  Verify: the new "reports an expired membership only once across runs" test
  should FAIL now (red), pass after the fix.
