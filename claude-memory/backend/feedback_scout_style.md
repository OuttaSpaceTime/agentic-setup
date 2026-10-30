---
name: Scout style — challenge scope creep and trace authorization implications
description: Felix uses scouts to challenge team decisions, not just to understand code. Wants authorization blast radius traced explicitly.
type: feedback
---

When scouting, Felix wants to understand implications deeply enough to challenge the team. He cares about:
- Why issues are bundled in the same milestone (organizational vs technical dependency)
- Authorization blast radius — trace every call site that uses a changed scope
- Whether unplanned follow-up work exists that nobody has tickets for yet
- Formulating precise, code-referenced MR feedback

**Why:** In the 2026-04-08 scout, Felix specifically asked to "challenge the person on implications" and "what issues are we expecting that haven't been planned for." He used the scout output to draft MR comments with code snippets.

**How to apply:** When running /scout, go beyond code understanding — surface organizational questions (why is this in this milestone?), trace authorization implications through all call sites, and proactively list unplanned follow-up work.
