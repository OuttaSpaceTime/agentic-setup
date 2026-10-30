---
name: project-workflow-session-limit-recovery
description: Recover a Workflow run killed by the session token limit via journal.jsonl + resumeFromRunId
metadata: 
  node_type: memory
  type: project
  originSessionId: d63bd075-d785-496b-b49b-d5ababae5dd6
  modified: 2026-09-08T21:27:47.712Z
---

When a Workflow run dies mid-flight (session limit, interrupt), completed agent results are already
durable in `<transcriptDir>/journal.jsonl` — one `{"type":"result",...}` line per finished agent.
The lines carry no `label`, only `key`/`agentId`/`result`, so classify recovered results by their
schema shape (e.g. `'surface' in r` = a map agent, `'candidates' in r` = a finder, `'verdict' in r`
= a verifier).

Then relaunch with `Workflow({scriptPath, resumeFromRunId})` — unchanged `(prompt, opts)` agents
replay from cache for free and only the dead ones re-run.

**Why:** a large fan-out can burn millions of subagent tokens before dying, and the default
assumption that the run is lost throws all of it away. On 2026-09-08 a 139-agent audit died with 67
agents done; resuming re-ran only the 72 failures.

**How to apply:** read journal.jsonl BEFORE diagnosing an empty/null result — the top-level return
value can be null while every upstream stage succeeded. Beware: editing any agent's opts invalidates
that call site's cache, so make model/prompt edits only to stages you intend to re-run.
See [[feedback-sonnet-subagents]].
