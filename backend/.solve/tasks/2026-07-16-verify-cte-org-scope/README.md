# Verify org-scoped CTE query

Checks whether `relation_class.with_recursive(...).from("descendants AS <table>")`
(without `.unscoped`) actually carries the `OrgScoped` default_scope WHERE clause
into the final SELECT against the CTE output — i.e. does default_scope re-filter
the CTE's `organization_id` column, or does `.from` with an aliased CTE bypass it.

## 01-print-sql.rb

Run with `bin/rails runner`. Sets `Current.organization`, builds the org_id-carrying
CTE query (the version without `.unscoped`), and prints `.to_sql` so we can see
whether the default_scope WHERE clause is present in the final query.

Verify: read the printed SQL for a `WHERE ... organization_id = ` clause on the
outer SELECT (not just inside the CTE's anchor/recursive terms).
