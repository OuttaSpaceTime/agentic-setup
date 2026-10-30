---
name: user_tool_migration
description: Felix migrated from Codex + Cursor to Claude Code on 2026-03-26 — skill inventory and decisions
type: project
---

On 2026-03-26, Felix fully migrated from Codex CLI and Cursor IDE to Claude Code as his primary AI tool.

**Why:** Consolidate skills/commands/prompts that were scattered across 3 tools into one place.

**How to apply:** All workflow skills are now in `~/.claude/skills/`. Don't reference Codex or Cursor commands. The only remaining Codex skill is `uv-jupyter-repo-setup`. Historical artifacts remain in `.codex/docs/` directories.

Skills (as of 2026-04-08): scout, plan, review, sketch, walkthrough, card, control-flow-trace, d2, diff-review, explore-solutions, research, write-claude-rules, autoresearch. Portal-specific: db-reset, db-import.

Note: `strict-diff` was removed (2026-04-07) in favour of `diff-review`.
