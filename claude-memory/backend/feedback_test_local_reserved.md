---
name: feedback-test-local-reserved
description: test/local/ is reserved for migration tests and tests of untracked local helpers — nothing else
metadata:
  type: feedback
---

`test/local/` holds exactly two kinds of file:

1. Migration tests, one per data migration (`<migration_name>_test.rb`).
2. Tests whose *subject* is an untracked local helper — currently only `migration_scope_guard_test.rb` and `fixture_console_helpers_test.rb`.

**Why:** `test/local/` is untracked (`.git/info/exclude`), so anything parked there never runs in CI, no colleague sees it, and it rots as the branch moves on. On 2026-09-15 Felix found Claude had scattered a perf probe (`inbox_n_plus_one_test.rb`) and a stale security audit (`tlp_support_dropped_reason_leak_test.rb`, already superseded by `test/integration/security/tlp_amber_strict_leak_test.rb`) into worktree copies of it. Both were deleted, as was `fake_auth0_userinfo_test.rb` — its subject `lib/omni_auth/strategies/fake_auth0.rb` is tracked, so it did not qualify even though the strategy is dev-only.

**How to apply:** A test of committed code goes in the committed tree (`test/models/`, `test/integration/`, `test/serializers/`, `test/lib/`) even when it is a one-off you will throw away. A throwaway *measurement* (query counts, N+1, timing) is not a test — write it as a scratchpad script (`script-performance` skill). The rule lives in `.claude/rules/320-migration-tests.md`; since `.claude/` and `CLAUDE.md` are untracked, a rule edit in main must be rsynced to every worktree (or `worktree.sh repair`) — `CLAUDE.md` is not copied to worktrees at all, so rules must carry their own `paths:` frontmatter to load there.

Related: [[project-local-helpers-manual-worktree-sync]], [[project_migration_scope_guard]], [[feedback-migrations-must-be-generated]]
