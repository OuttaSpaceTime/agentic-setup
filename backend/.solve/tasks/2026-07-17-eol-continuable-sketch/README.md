# EOL Continuable delivery-job sketch

`delivery_job.rb` holds the corrected `ActiveJob::Continuable` sketch (uses
`step.set!` for UUID cursors, not `advance!`). `01-copy-to-clipboard.sh` pipes
that file into the Wayland clipboard via `wl-copy`.

Run: `bash .solve/tasks/2026-07-17-eol-continuable-sketch/01-copy-to-clipboard.sh`
Verify: paste (Ctrl+V) — the corrected sketch appears.
