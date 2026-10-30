---
name: feedback-shared-test-module
description: share tests across endpoints via an included module whose tests call methods each test class implements; never reflect/guess the target
metadata:
  node_type: memory
  type: feedback
  originSessionId: 1af46a83-530a-4eea-a95b-24e8892f40f1
  modified: 2026-09-29T15:46:54.583Z
---

To run the same tests against several endpoints, write a module (`extend(ActiveSupport::Concern)`, tests inside `included do … end`) whose tests call methods the including test class implements (e.g. `pagination_membership`, `pagination_path(**params)`, `paginated_ids`). Example: `test/support/keyset_pagination_tests.rb`.

**Why:** reviewer rejected a generic helper that derived the model from routes via `eager_load!` + reflection ("too generic, let the tests implement a method"). The shared-method shape also dissolves reek DataClump on helpers that threaded `(membership, path)`.

**How to apply:** `test('…')` inside a plain module resolves to `Kernel#test` and raises ArgumentError — use the Concern `included` block. Expected values stay DB queries per class ([[feedback-expected-values-from-query]]); don't make a helper method mutate fixtures, keep such a test local instead.
