# bash .solve/tasks/2026-10-27-agentic-setup-audit/current.sh
# Checks: which agent-setup files git ignores (local-only) and which rules load unscoped
# Look at: every line under "ignored" is invisible to the team; "unscoped" rules load every session
echo "== ignored (path <- rule)"; git check-ignore -v CLAUDE.md .claude/rules/030-code-style.md .claude/skills/db-reset/SKILL.md .claude/hooks/prefer-fixtures.sh bin/test bin/quality config/initializers/migration_scope_guard.rb test/local
echo "== tracked agent files"; git ls-files AGENTS.md CLAUDE.md .claude opencode.json
echo "== unscoped rules (no paths:)"; for f in .claude/rules/*.md; do grep -q '^paths:' "$f" || echo "$f"; done
