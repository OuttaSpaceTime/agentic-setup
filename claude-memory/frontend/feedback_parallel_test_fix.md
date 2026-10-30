---
name: feedback_parallel_test_fix
description: When fixing test failures, use parallel agents and only fix tests — never touch application code unless strong evidence of a bug
type: feedback
---

When running the full test suite to catch failures, spawn parallel agents to fix each failing test independently. Strict boundary: only fix test code, never touch application code. Only report back that application code may be broken when there is strong evidence.

**Why:** Felix explicitly requested this workflow (2026-03-27): "run subagents to run npx ng test for complete test suite and report back all failures, then spawn agents to fix failing tests, only fix tests do not touch the application, only when strong evidence report back that the application code may be broken."

**How to apply:** When asked to fix test failures or verify the test suite, first run the full suite, collect all failures, then spawn parallel agents — one per failing spec or group — with the explicit instruction to only modify test files. Escalate to Felix if a test failure clearly points to an application bug rather than a test issue.
