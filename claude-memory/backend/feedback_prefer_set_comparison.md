---
name: prefer-set-comparison
description: "In tests compare collections with assert_equal_set, never sort both sides of assert_equal"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4ae58f65-ee68-4b9f-a64b-bbff44db96d6
  modified: 2026-09-03T14:17:55.113Z
---

When asserting that two collections hold the same records/ids, use the project's `assert_equal_set(expected, actual)` helper (`test/test_helper.rb:77`, `assert_equal(Set.new(expected), Set.new(actual))`). Never write `assert_equal(expected.sort, actual.sort)` or add `.sort_by(&:id)` / `.order(:id)` just to make two sides line up.

**Why:** sorting states an ordering the assertion does not actually care about, so the reader cannot tell whether order is part of the claim. It also invites a second bug — `assert_equal(relation.order(:id), fixtures_array)` passes only while the fixture array happens to be in id order. Set comparison says exactly what is meant: same members, order irrelevant. Reserve an ordered `assert_equal` for cases where the order *is* the behaviour under test (a `sort` param, a cursor-paginated page).

**How to apply:** `assert_equal_set([a.id, b.id], relationship_ids('children').flatten)` rather than `assert_equal([a.id, b.id].sort, relationship_ids('children').flatten.sort)`. Works in model and integration tests alike. Related: [[feedback_avoid_unnecessary_to_a]], [[feedback_test_description_style]].
