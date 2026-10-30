# Memory Index

- [project_claude_rules.md](project_claude_rules.md) — Claude rules created for this project, what was excluded, and April 2026 additions from PR review
- [user_learning_philosophy.md](user_learning_philosophy.md) — Felix's interactive skill philosophy: guided/unguided learning, info density limits
- [user_tool_migration.md](user_tool_migration.md) — Full migration from Codex+Cursor to Claude Code (2026-03-26)
- [feedback_present_options.md](feedback_present_options.md) — Present 2-3 options with tradeoffs at decision points, not just one proposal
- [feedback_collaborative_workflow_design.md](feedback_collaborative_workflow_design.md) — Skills should help users figure out HOW to measure, not assume they know
- [feedback_parallel_test_fix.md](feedback_parallel_test_fix.md) — Fix tests with parallel agents; never touch app code unless strong evidence of a bug
- [feedback_pr_review_workflow.md](feedback_pr_review_workflow.md) — When PR review comments are pasted, evaluate for rule additions; Niklas Häusele is the team maintainer
- [feedback_isdevmode_over_token.md](feedback_isdevmode_over_token.md) — Prefer isDevMode() over DEVMODE token; test it via global ngDevMode (spyOn fails under esbuild)
- [project_autoresearch_skill.md](project_autoresearch_skill.md) — Autoresearch skill: complete, tested, at ~/.claude/skills/autoresearch/
- [project_create_worktree_skill.md](project_create_worktree_skill.md) — create-worktree skill: builds vilocify worktrees that compile/test (node_modules symlink + .claude copy)
- [project_inbox_json_mrs.md](project_inbox_json_mrs.md) — inbox JSON rendering MRs #591/#592 state; per-worktree backend DBs; seed scripts
- [feedback_npm_security_baseline.md](feedback_npm_security_baseline.md) — Felix's ignore-scripts/min-release-age npm settings are intentional org policy; never loosen, fix per-package instead
- [feedback_lint_fix_scope.md](feedback_lint_fix_scope.md) — `ng lint --fix` reformats unrelated files; revert them after linting
- [Questions in prose](feedback_questions_in_prose.md) — explain, then ask design questions in chat; AskUserQuestion dialog only for permission prompts
