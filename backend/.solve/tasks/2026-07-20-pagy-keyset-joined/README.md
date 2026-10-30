# pagy keyset joined-column failure — locate the exact failing line

Pagy's AR keyset adapter drops the table in `extract_keyset` (adapter L10),
keeping only the bare column symbol, then reads it off the BASE record via
`record.slice` (adapter L15). `slice` uses `public_send`, so:

- `:id` exists on the base record  -> returns wrong value silently (no raise)
- `:name` / `:identifier` do NOT  -> NoMethodError

## 01-slice-asymmetry.rb
Isolates adapter L15's mechanism with no DB: calls `Notification.new.slice(...)`
for `:id` (works) and `:identifier` (raises), printing each outcome.

Run:  bin/rails runner .solve/tasks/2026-07-20-pagy-keyset-joined/01-slice-asymmetry.rb
Verify: prints `id => {...}` then a NoMethodError for `identifier`.
