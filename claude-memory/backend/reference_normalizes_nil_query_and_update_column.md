---
name: reference-normalizes-nil-query-and-update-column
description: Rails normalizes — nil in a where is NOT normalized, but update_column IS, so it cannot exercise a NOT NULL constraint
metadata:
  type: reference
---

Rails 8.1.3.1, verified in vilocify-portal on 2026-09-21 with `normalizes_to_empty_string` on `Component`:

- `Component.where.not(vendor: nil).to_sql` → `"vendor" IS NOT NULL` — the predicate builder short-circuits on nil *before* the normalized type serializes, so normalization never runs. After a NOT NULL migration that query matches every row. To exclude blank values you must write the normalized value yourself: `where.not(vendor: '')` → `"vendor" != ''`.
  The exact reason is `ActiveRecord::Relation::QueryAttribute#nil?` (activerecord `lib/active_record/relation/query_attribute.rb:37`): it returns `value_before_type_cast.nil? || ...`, so a raw `nil` short-circuits on the *pre-cast* value and Arel's `visit_Arel_Nodes_Equality` emits `IS NULL` without ever calling `serialize`. `apply_to_nil: true` does not change this — it only affects `cast`, which the writer path uses (`where(url: nil).new.url` → `""`). A non-nil value is normalized in SQL (`where(url: 'FOOBAR')` → `= 'foobar'`), which is why a reviewer probing with a non-nil string sees normalization work.
- **Not documented outside the Rails source.** The `normalizes` API docs and the 7.1 release notes say only "normalization will not be applied to nil values … `:apply_to_nil`" and never mention queries. Rails' only nil-query test (`activerecord/test/cases/normalized_attribute_test.rb:40`, from issue #53564 / PR #53580) asserts `where(name: nil).to_sql == where(name: '').to_sql` for the `'' -> nil` direction only. Verified our `nil -> ''` direction breaks that same invariant (`IS NULL` vs `= ''`) and has no Rails test. So in review, cite the source line + a `to_sql` probe, not docs. Reported upstream 2026-09-21 as rails/rails#58836 (asks for fix-or-document); standalone repro app at `~/Code/normalizes-probe` (vanilla `rails new` baseline commit + 6 lines on top: `blank_as_empty` NOT NULL DEFAULT '' with apply_to_nil, `blank_as_null` nullable with presence, one fixture).
- `update_column(:eol_reached, nil)` persists `false`, and `update_column(:vendor, nil)` persists `''` — `update_columns` goes through `write_cast_value`, which applies the normalizer. So `update_column(col, nil)` can never trigger an `ActiveRecord::NotNullViolation`; only raw SQL can: `Model.unscoped.where(id:).update_all('col = NULL')`.
- Consequence for tests: a "normalizes nil to X" test written as `update!(col: nil)` is still red without the normalizer once the DB column is NOT NULL — it raises `NotNullViolation` instead of failing the assertion.
- `assert_equal(false, x)` cannot be used to pin false: RuboCop `Minitest/RefuteFalse` + `Rails/RefuteMethods` autocorrect it to `assert_not(x)`.

Related: [[feedback-test-deletion-pattern]], [[reference-default-scope-write-precedence]]
