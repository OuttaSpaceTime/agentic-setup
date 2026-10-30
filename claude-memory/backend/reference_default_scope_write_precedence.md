---
name: reference_default_scope_write_precedence
description: ActiveRecord default_scope beats explicit attributes for insert_all/upsert_all but loses to them for new/create/update
metadata: 
  node_type: memory
  type: reference
  originSessionId: 4ad94eb2-9889-48a6-b1cd-ddd70e128dfd
  modified: 2026-07-31T04:14:00.917Z
---

A `default_scope` containing `where(col: x)` and/or `create_with(col: y)` collapses into one hash via `Relation#scope_for_create` (`activerecord/lib/active_record/relation.rb:1251-1255`; `create_with` overwrites the where-equality). That hash is then applied with **opposite precedence** depending on the write path:

- **SCOPE WINS** — `insert_all`, `insert_all!`, `upsert_all`, `insert`, `insert!`, `upsert`. `insert_all.rb:76` is `attributes.merge!(@scope_attributes)`: your row hash is the receiver, the scope hash the argument, so the scope overwrites your value. `insert_all.rb:35-37` also forces the column into the INSERT column list even if no row mentions it. (Line 77 uses `reverse_merge!` for timestamps — the asymmetry is deliberate.) These are class-level `delegate(..., to: :all)` (`querying.rb:22-24`), so `Model.insert_all` is `Model.all.insert_all`.
- **EXPLICIT WINS** — `new`, `build`, `create`, `create!`, `first_or_create`, `find_or_create_by`, `update`, `update!`, `update_all`. `core.rb:477` assigns scope attributes, then `core.rb:479`'s `super` → `assign_attributes` applies the caller's hash last.

Only `unscoped` (or `create_with(nil)`) clears it. `unscope(where: :col)` does **not** — `:create_with` is absent from `VALID_UNSCOPING_VALUES` (`query_methods.rb:768-771`). `upsert_all` is worst: the scoped column survives into `DO UPDATE SET` (`insert_all.rb:57-59`), so an upsert retroactively re-forces the value on existing rows.

Verified against activerecord 8.1.2.1 and reproduced empirically. See [[reference_rewhere_vs_unscope_eager_load]].
