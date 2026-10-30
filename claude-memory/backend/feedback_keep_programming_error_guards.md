---
name: feedback-keep-programming-error-guards
description: "raises/nil checks that catch developer mistakes stay even when no current input reaches them; don't trim them as dead code"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 1af46a83-530a-4eea-a95b-24e8892f40f1
  modified: 2026-09-29T17:14:50.757Z
---

Guards that exist to catch programming errors (e.g. `KeysetPaginatable` raising `NotSeekable` when a sort column is nullable without a sentinel, or a nil value reaches `missing_keyset_value`) stay, even when every current input path makes them unreachable.

**Why:** Felix: "the nil checks are to prevent against programming errors" — he made me restore a raise I had trimmed as unreachable during /trim-code on branch 1123-keyset-2.

**How to apply:** in trims/simplifications, classify such guards like hostile-input checks: defense in depth, not dead code. Only propose removing one if he asks; keep their tests.
