---
name: feedback-one-subagent-per-request
description: "When Felix requests several code-review fixes, spawn one subagent per requested item rather than batching them"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d02f1f59-df2c-4f6a-91a3-3698bea25d7e
  modified: 2026-08-10T09:31:57.023Z
---

When Felix asks for multiple review findings to be applied, he wants **one subagent per requested item**, spawned as he asks for them — not one agent batching several findings, and not sequential work in the main thread. He states this as "always use one subagent per requested".

**Why:** each fix stays independently verifiable and independently revertable, and the agents run in parallel so a stream of requests doesn't serialize. He fires requests rapidly mid-turn and expects each to be picked up immediately.

**How to apply:** spawn immediately on each request, in the background, with the finding id in the description. Give each agent an explicit "touch only this file" constraint and name the files other concurrent agents are editing, since parallel agents on one repo will otherwise collide.

The one legitimate exception is findings that are **interdependent edits to the same file** — e.g. extracting a method that removes the very local another finding wanted renamed. Batching those into one agent is correct, but say so explicitly and explain the collision, rather than silently merging requests.

Related: [[feedback-suggest-names-in-chat]] still applies on top of this — if a requested fix is a rename, propose candidates and wait for the pick before spawning. Also [[feedback-never-commit]] — agents must be told not to commit or stage.
