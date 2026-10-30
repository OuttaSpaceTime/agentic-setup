---
name: feedback-expected-values-from-query
description: "In integration tests, derive expected values (e.g. the next-page cursor) from a DB query, never from the response under test"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 02e400d7-1279-4a60-b71e-8b1f1f124619
  modified: 2026-09-24T11:58:31.817Z
---

Build the expected value of an integration assertion from an independent database query (e.g. `set_current_for(...) { Model.order(:id).take(2).last }`), not from the response being asserted (`response_ids.last`).

**Why:** Felix rejected replacing the query with `response_ids.last` in the top-level links tests, even though it would have cleared a flay duplication finding: "must match against the query instead". Reading the expectation back from the response only checks that the response agrees with itself.

**How to apply:** when a test's expected value duplicates across files, and flay or reek flags it, don't switch it to the response to dedupe. Keep the query, or leave the duplication (JRY). Related: [[feedback-prefer-set-comparison]].
