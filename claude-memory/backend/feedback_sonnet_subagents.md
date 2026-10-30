---
name: feedback-sonnet-subagents
description: "Use Sonnet for bulk/mechanical workflow subagent stages, reserve Opus for synthesis"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d63bd075-d785-496b-b49b-d5ababae5dd6
  modified: 2026-09-11T15:26:58.000Z
---

Felix asks for Sonnet subagents on cost grounds when a workflow fans out widely. Split the fleet by where
model quality actually changes the answer: `model: 'sonnet'` on the high-count mechanical stages
(verify-is-it-covered, refute, probe, sweep), and leave the low-count cross-cutting stages
(critic, synthesize) on the inherited Opus.

**Why:** a fan-out audit spends ~90% of its agents on grep-and-read verification, which Sonnet does
as well as Opus at a fraction of the cost. The reasoning that benefits from Opus is the small number
of agents that read across everything at once.

**How to apply:** author the workflow without model overrides, then add them per call site. Note the
cache trade-off — the Workflow resume cache keys on `(prompt, opts)`, so adding `model:` to a stage
invalidates that stage's already-completed results. Preserve the expensive upstream stages
(map/finder/dedup) by leaving their opts untouched. See [[project-workflow-session-limit-recovery]].

**Escalation, 2026-09-11:** mid-session Felix may narrow this to *only* Sonnet — "when done only spawn
sonnet subagents to finish all tasks to save tokens" — including the stages this note would otherwise
leave on Opus, and including agents that apply fixes rather than just read. Treat a cost instruction
as covering every subsequent spawn until he says otherwise, and do the cross-cutting synthesis in the
main thread instead of buying it with an Opus subagent. Combine with
[[feedback-one-subagent-per-request]]: one agent per coherent change, but do not fragment a single
cleanup across three agents just to honour the one-per-fix rule when he has asked to save tokens.
