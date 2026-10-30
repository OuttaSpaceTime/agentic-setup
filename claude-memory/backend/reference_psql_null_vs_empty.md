---
name: reference-psql-null-vs-empty
description: psql prints NULL and the empty string identically — set \pset null before any migration before/after snapshot
metadata:
  type: reference
---

psql renders NULL and `''` as the same empty cell in both aligned and unaligned output, so a
`diff -u` of before/after snapshots shows **no change** for a `NULL -> ''` backfill. Always
`\pset null '<NULL>'` in a snapshot script.

Also use `\pset format unaligned` with `\pset fieldsep`: aligned output recomputes column widths
per result set, so the after-snapshot reformats every line and the diff becomes unreadable.

Hit in-session (BE-1279): the first Procedure A pass silently reported "no cell changed" for four
of six data migrations, all of which were `NULL -> ''`.

Related: [[reference-migration-invoke-change-only]]
