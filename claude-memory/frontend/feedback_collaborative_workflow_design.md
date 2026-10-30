---
name: feedback_collaborative_workflow_design
description: Tools/skills should help users figure out HOW to measure or validate, not assume they know upfront
type: feedback
---

Don't assume the user knows the best approach, metric, or validation strategy upfront — helping them discover that is often the most valuable part.

**Why:** During autoresearch skill design (2026-03-26), Felix emphasized: "the thing i don't know before hand for difficult cases the skill will help me find out the best approach" and "in some cases designing a repeatable workflow may be part of the skill." He rejected designs that required the user to provide a metric command or test scenarios as input — the skill should research the target and propose those.

**How to apply:** When building skills or tools that involve a setup phase, include a research step where Claude examines the target, then proposes the workflow (measurement, validation, scope) collaboratively. The user provides the goal; Claude helps figure out the how.
