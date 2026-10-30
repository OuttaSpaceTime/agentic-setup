# Is sorting on a joined column slow, and does incremental sort rescue it? (#1123)

Incremental sort only helps when an index delivers a prefix of the ORDER BY.
Leading (joined) sort column, and the btree available:
- Component vendor `component_vendors.name` — no btree (only GIN trgm)
- Component name `component_names.name` — no btree (only GIN trgm)
- Membership `users.name` — btree `index_users_on_name`
- Membership `users.email` — btree unique

## 01-benchmark-joined-sort-incremental.rb
Seeds a realistic dataset in a rolled-back transaction, then EXPLAIN (ANALYZE)
each sort with enable_incremental_sort ON vs OFF, page 1 vs deep offset.
Run: bin/rails runner .solve/tasks/2026-07-20-incremental-sort-joined-order/01-benchmark-joined-sort-incremental.rb
