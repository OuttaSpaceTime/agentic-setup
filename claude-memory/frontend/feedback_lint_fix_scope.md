---
name: feedback-lint-fix-scope
description: "`ng lint --fix` reformats unrelated files (union-type line splits); revert anything outside the task's files afterwards"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 9d3d388f-ebee-4ca1-9251-99f763f78253
  modified: 2026-10-05T13:51:21.809Z
---

`npx ng lint --fix` (required by the 800-code-verification rule) rewrites many unrelated files, e.g. splitting `type X = 'a' | 'b'` into leading-pipe multi-line unions. Felix asked to revert these ("lint changed too much").

**Why:** Unrelated formatting churn pollutes the diff/MR.

**How to apply:** After running `ng lint --fix`, check `git status`; restore every file outside the task's scope with `git restore --source=HEAD --staged --worktree -- <files>` (after checking the diff is formatting-only).
