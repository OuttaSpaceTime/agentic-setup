---
name: project_autoresearch_skill
description: Global autoresearch skill at ~/.claude/skills/autoresearch/ — complete, tested, ready for use
type: project
---

Global skill at `~/.claude/skills/autoresearch/` (SKILL.md + references/session-schema.md). Created 2026-03-26, inspired by karpathy/autoresearch and davebcn87/pi-autoresearch.

Two modes:
- **Metric mode**: numeric optimization (test speed, bundle size, strict errors, ML metrics)
- **Exploration mode**: qualitative discovery (skills, rules, prompts, architecture) via blind A/B comparison

Key design decisions:
- Collaborative setup phase — skill researches target, proposes 2-3 options per dimension (measurement, validation, scope) with tradeoffs
- Designing the measurement approach is part of the skill's value (vague goals welcome)
- Session persistence via `.autoresearch.md` + `.autoresearch.jsonl` for cross-conversation resume
- Git as safety net; non-git dirs get temporary `git init` (cleaned up on session end)
- Stack-agnostic examples (Python, generic) — works outside Angular
- Tested against 6 scenarios: metric/Angular, explore/rule, vague goal, Python, resume, skill improvement

**Why:** Felix wanted a single skill for both "optimize this number" and "discover the best approach" workflows, usable across any project and any type of target (code, skills, rules, prompts).

**How to apply:** Invoke with `/autoresearch` or when Felix mentions optimization loops, iterative experimentation, or autonomous improvement.
