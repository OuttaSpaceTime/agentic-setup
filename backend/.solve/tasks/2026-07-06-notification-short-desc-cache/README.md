# Notification item short_description_index cache

`NotificationEventProcessJob` uses `Inbox::Item.insert_all`, which skips the
`before_create` callback that sets `short_description_index` (search cache)
and `item_type_cache`. The latter was already fixed in 936a803d0; this task
fixes `short_description_index` for the same job, and backfills existing rows.

## Scripts

- `01-run-notification-job-test.sh` — runs the job test file to confirm the
  new assertion on `short_description_index` fails before the fix, then
  passes after.
