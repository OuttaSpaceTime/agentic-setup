---
name: feedback_pr_review_workflow
description: When Felix pastes PR review comments from maintainer, evaluate each for rule/memory additions — don't just apply fixes
type: feedback
---

When Felix pastes maintainer PR review comments, use the `review-feedback` skill (since 2026-10-28), which encodes this workflow:
1. Sketch each thread's fix first, and apply only after his go. Agents that applied straight away got stopped ("stop sketch only!!!!").
2. Evaluate each comment: does it reveal a project pattern Claude should always follow that isn't already captured in `.claude/rules/`?
3. If yes — propose adding or updating the rule and wait for confirmation ("good add these")

**Why:** In the 2026-04-01 session, Felix pasted Niklas Häusele's review of the inbox scaffold PR and explicitly said: "most of them are AI slop, please check if something may be worth adding to our memory/rules/claude.md. discern what is relevant for this project vs. what just may be missed vs. what the model should already know and do correctly."

**How to apply:** Treat maintainer PR comments as a signal about gaps between Claude's output and the team's standards. Read the existing rules first to avoid duplicating what's already there. Only propose rule additions for things that are project-specific or that Claude repeatedly gets wrong — not general Angular/TS best practices.

**Team context:** Niklas Häusele (`@niklas.haeusele.ext`) is the team maintainer who reviews PRs. His comments are authoritative about project conventions.
