---
name: Prefer hooks for behavioral enforcement
description: Felix prefers deterministic hooks over CLAUDE.md instructions for constraining Claude's behavior
type: feedback
---

Use hooks (PreToolUse, PostToolUse) for behavioral constraints rather than relying on CLAUDE.md instructions alone.

**Why:** Team discussion (2026-03-27) revealed that prompt-based instructions are unreliable — Claude still pipes test output despite rule 800 saying not to. Hooks are deterministic: they run every time, can't be ignored, and don't cost extra tokens to enforce. Felix explicitly chose to explore hooks as the solution.

**How to apply:** When Felix asks to enforce a behavioral constraint (e.g., "don't do X when running Y"), suggest a hook implementation rather than adding another CLAUDE.md rule. Reserve CLAUDE.md for project context, conventions, and architecture — not for how Claude should do its work.
