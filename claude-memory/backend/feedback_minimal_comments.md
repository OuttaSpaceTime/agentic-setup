---
name: feedback_minimal_comments
description: Write almost no comments — even explanatory prose about non-obvious behavior should be omitted unless the code genuinely cannot speak for itself
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 20cf7d87-89e1-4243-b8be-f7d2c07df78d
  modified: 2026-09-11T14:45:00.127Z
---

Write almost no comments. The project rules already say no comments for self-explanatory code, but Felix wants this applied very aggressively: even multi-line explanatory comments about non-obvious design decisions (e.g. why a set intersection is used, why cursor links round-trip a param) should be omitted. Let the code stand alone.

**Why:** Felix removed all comments from `ApplicationSerializer#initialize` that I had added to explain the opt-in paginated relationship logic. They were accurate but unwanted.

**How to apply:** Default to zero comments. Only add one if the code would genuinely mislead a future reader without it — a workaround for a specific external bug, a hidden constraint that isn't visible from the code at all. "This is why we do X" prose explanations don't qualify.

**Amendment (2026-09-10), reversed (2026-09-11):** the module/class-comment exception (added so reek's `IrresponsibleModule` could be satisfied with a real comment) is gone — Felix disabled `IrresponsibleModule` in `.reek.yml` again (`enabled: false`), removing the need for it.

**Current rule (2026-09-11):** almost no comments, full stop. When one of the three listed exceptions genuinely applies, the comment must be **1–2 lines max** — never a paragraph or comment block. `.claude/rules/040-comments.md` was updated to state this length cap explicitly.
