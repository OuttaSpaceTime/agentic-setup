---
name: feedback_table_name_length
description: "When a Rails class rename makes a derived table name exceed 63 chars (Postgres limit), pin the old name with self.table_name instead of renaming the DB table"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: dc422e05-56a4-4a07-a636-4d89543e2fb5
---

When renaming a model causes the Rails-derived table name to exceed PostgreSQL's 63-character limit, keep the original (shorter, possibly abbreviated) table name in the DB and add `self.table_name = '...'` to the model.

**Why:** `monitoring_list_notification_revision_event_end_of_life_components` is 66 chars — Postgres rejects it at schema load time. The abbreviated DB name (`_eol_components`) is fine as an implementation detail.

**How to apply:** Before committing a model rename, count the derived table name. If > 63 chars, add `self.table_name` and leave the migration/schema table name unchanged. See [[feedback_belongs_to_namespace_defaults]].
