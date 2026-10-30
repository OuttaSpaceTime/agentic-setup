# Copy pagination table to clipboard

Copies the joined-table-order pagination inventory (markdown table) to the
system clipboard via `wl-copy` (Wayland session).

## Script

- `01-copy-table.sh` — pipes the markdown table into `wl-copy`.

## Verify

Run the script, then paste anywhere (e.g. `wl-paste` or Ctrl+V) to confirm.
