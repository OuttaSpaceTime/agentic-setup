---
name: reference_rewhere_vs_unscope_eager_load
description: "To lift a default_scope through an eager-loaded association use unscope(where:), never rewhere — rewhere cannot touch the JOIN's ON clause"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 4ad94eb2-9889-48a6-b1cd-ddd70e128dfd
  modified: 2026-07-31T04:14:12.859Z
---

A scope meant to *undo* a model's `default_scope` (e.g. `Component.with_restricted` lifting `where(tlp_amber_strict: false)`) must use `unscope(where: :col)`, not `rewhere(col: [...])`.

When an association is **eager loaded** (`includes(...)` resolving to a LEFT OUTER JOIN — e.g. `MonitoringList.includable` → `includes(:visible_components)`), the joined model's default scope is emitted into the JOIN's **ON clause**:

```sql
LEFT OUTER JOIN "components" ON "components"."tlp_amber_strict" = FALSE AND ... WHERE "components"."tlp_amber_strict" IN (TRUE, FALSE)
```

`rewhere` only rewrites the WHERE clause, so the ON clause still filters the rows out — the records silently vanish from every serialized relationship payload while a direct association query (`ml.visible_components.ids`) still looks correct. That split is what makes the bug so easy to miss: model-level tests pass, request-level relationship tests fail.

`unscope(where: :col)` removes the predicate from the relation's where_clause entirely, so it never reaches the ON clause. It also restores plain preloading (two queries) instead of forcing the eager_load JOIN, which changes `assert_queries_count` expectations back to their pre-default-scope values.

Note `unscope` still cannot remove `create_with` — see [[reference_default_scope_write_precedence]].
