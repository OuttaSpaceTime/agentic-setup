---
name: suggest-names-in-chat-first
description: "When asked for better variable/method names, list candidates in chat before touching the file"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 6f78f5a3-e234-47ad-ad89-acc5a6bc2d6d
  modified: 2026-08-03T14:53:37.897Z
---

When Felix asks for a more readable name, propose the candidate names (and the shape they produce) in chat and wait for his pick — do not apply a rename and report it as done.

**Why:** naming is his taste call, and an applied rename forces him to review a diff he did not choose; seeing 2-3 candidates side by side is how he decides.

**How to apply:** answer with the options plus a one-line rationale each and a recommendation, then stop. Same for renames that follow from a review comment. Related: [[feedback_never_commit]], [[feedback_minimal_comments]].
