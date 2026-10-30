---
name: never-pipe-test-output
description: Test commands must never be piped through grep/head/tail — always capture full output in one run
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 72b46efc-3c7f-4371-a3bd-78871ffc5db4
---

Never pipe test command output through `grep`, `head`, `tail`, or any filter.

**Why:** Piping hides error details, forcing a second test run to see what actually failed. This doubles execution time and token cost. Rule 800 in `.claude/rules/800-quality-tools.md` already says "do NOT pipe output" but this is the hard enforcement rationale.

**How to apply:** Always run `bin/rails test <paths>` bare (with `2>&1` if needed for stderr). Read the full output. If output is long, that's fine — the details are worth more than the tokens saved by filtering. The `no-pipe-tests.sh` PreToolUse hook that previously enforced this was removed on 2026-06-17.
