---
name: pretty-sql-in-probes
description: "Pretty-print SQL in probe scripts via pg_query's deparser, colorize with pygmentize"
metadata:
  node_type: memory
  type: reference
  originSessionId: b6ec0c17-f99b-445a-9cb6-ee7f02ffcf0e
  modified: 2026-10-01T13:10:10.210Z
---

`PgQuery.parse(sql).deparse(opts: PgQuery::DeparseOpts.new(pretty_print: true, indent_size: 2, max_line_length: 100))` — pg_query 6.2.2 is already in the Gemfile. Drops `/*application=…*/` comments, doesn't wrap long `IN (…)` lists, has no color option.
Colors: pipe the script output through `pygmentize -l sql` (installed system-wide).
Example: `.solve/tasks/2026-10-01-ml-index-component-preload/current.rb`
