# Investigate oasdiff --auto-upgrade rejection

`bin/oasdiff` calls `oasdiff breaking ... --auto-upgrade`. The claim is the
installed binary rejects that flag.

- `01-check-flags.sh` — print oasdiff version and grep its `breaking` help for
  the upgrade flag, so we know the correct flag name (or that it's gone).

Run: `bash .solve/tasks/2026-07-16-oasdiff-flag/01-check-flags.sh`
Verify: output shows the installed version and whether `--auto-upgrade` exists.
