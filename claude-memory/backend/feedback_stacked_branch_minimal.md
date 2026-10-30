---
name: stacked-branch-minimal
description: "In a stacked MR series, each branch holds only the code it needs itself; never pre-shape an earlier branch for a later one"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 807aaf3a-7f10-423c-a782-af5eae97e95d
  modified: 2026-09-24T15:44:44.800Z
---

In a stacked branch series (e.g. 1123-keyset-2 … -6), never change an earlier branch just so a later branch can pass. If branch 6 needs a new parameter, hook or signature, add it in branch 6, even when that means 6 touches files that 2 introduced.

**Why:** the user wants every branch's code to be the minimum that branch itself needs. An unused parameter or a hook added "for later" is speculative code the reviewer of the earlier MR can't justify.

**How to apply:** when a later branch needs an API change in an earlier branch's code, make the change in the later branch's own commit. Only change the earlier branch when that branch needs the change itself. Related: [[feedback-scout-style]].
