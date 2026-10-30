#!/usr/bin/env bash
# Run: bash .solve/tasks/2026-07-24-worktree-selftest/run.sh
MAIN="$HOME/Code/Vilocify/vilocify-portal"
WORKTREES="$HOME/Code/Vilocify/worktrees"
SH="$MAIN/.claude/skills/create-worktree/scripts/worktree.sh"
WT="$WORKTREES/be-wt-selftest"
MARKER="$MAIN/.wt-selftest-marker"
PG=vilocifyportal-postgres-1
fails=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; fails=$((fails+1)); }

dbcount() { docker exec "$PG" psql -U postgres -tAc \
  "SELECT count(*) FROM pg_database WHERE datname LIKE '%be_wt_selftest%'"; }
cleanup() {
  git -C "$MAIN" worktree remove --force "$WT" 2>/dev/null || true
  git -C "$MAIN" branch -D wt-selftest 2>/dev/null || true
  docker exec "$PG" psql -U postgres -tAc \
    "SELECT 'DROP DATABASE IF EXISTS \"'||datname||'\";' FROM pg_database WHERE datname LIKE '%be_wt_selftest%'" \
    | { grep . || true; } | docker exec -i "$PG" psql -U postgres >/dev/null 2>&1 || true
  rm -f "$MARKER"
}
cleanup   # start from a clean slate

echo "### case 1: new branch without start-point must error"
out=$("$SH" create wt-selftest 2>&1); rc=$?
{ [ $rc -ne 0 ] && grep -q "needs a start-point" <<<"$out"; } && pass "arg validation" || fail "arg validation (rc=$rc): $out"
[ ! -e "$WT" ] && pass "no worktree left behind" || fail "worktree created on error"

echo "### case 2: happy-path create with extra file + missing file warning"
echo marker > "$MARKER"
out=$("$SH" create wt-selftest main .wt-selftest-marker nope-missing.xyz 2>&1); rc=$?
[ $rc -eq 0 ] && pass "create rc=0" || fail "create rc=$rc: $out"
[ -d "$WT" ] && pass "worktree dir exists" || fail "worktree dir missing"
git -C "$MAIN" worktree list | grep -q "be-wt-selftest" && pass "listed in worktrees" || fail "not listed"
grep -qE 'database: vilocify_portal_dev_be_wt_selftest' "$WT/config/database.yml" && pass "dev db suffixed" || fail "dev db not suffixed"
grep -qE 'database: vilocify_portal_test_be_wt_selftest' "$WT/config/database.yml" && pass "test db suffixed" || fail "test db not suffixed"
git -C "$WT" status --porcelain | grep -q "config/database.yml" && fail "database.yml edit not hidden" || pass "database.yml hidden (skip-worktree)"
[ -f "$WT/.wt-selftest-marker" ] && pass "extra file copied" || fail "extra file not copied"
grep -q "nope-missing.xyz" <<<"$out" && pass "missing extra warned" || fail "no warning for missing extra"
[ -f "$WT/config/initializers/scope_console_helpers.rb" ] && pass "unscope helper copied" || fail "scope_console_helpers.rb not copied"

echo "### case 3: creating over an existing worktree must error"
out=$("$SH" create wt-selftest main 2>&1); rc=$?
{ [ $rc -ne 0 ] && grep -q "already exists" <<<"$out"; } && pass "duplicate guard" || fail "duplicate guard (rc=$rc): $out"

echo "### case 4: repair idempotent + trailing-slash path must not re-suffix DBs"
before4=$(dbcount)
out=$("$SH" repair "$WT/" 2>&1); rc=$?   # trailing slash mimics the ...worktrees/*/ glob loop
[ $rc -eq 0 ] && pass "repair rc=0" || fail "repair rc=$rc: $out"
after4=$(dbcount)
[ "$before4" -eq "$after4" ] && pass "no orphan DBs after trailing-slash repair ($before4)" || fail "orphan DBs created ($before4 -> $after4)"
grep -qE 'database: vilocify_portal_dev_be_wt_selftest' "$WT/config/database.yml" && pass "db still suffixed after repair" || fail "db suffix lost on repair"
git -C "$WT" status --porcelain | grep -q "config/database.yml" && fail "database.yml edit not hidden after repair" || pass "database.yml hidden after repair"

echo "### case 5: remove drops databases and worktree"
rm -f "$WT/.wt-selftest-marker"   # untracked extra would block git worktree remove
before=$(dbcount)
out=$("$SH" remove wt-selftest 2>&1); rc=$?
[ $rc -eq 0 ] && pass "remove rc=0" || fail "remove rc=$rc: $out"
[ ! -e "$WT" ] && pass "worktree dir gone" || fail "worktree dir still present"
git -C "$MAIN" worktree list | grep -q "be-wt-selftest" && fail "still listed after remove" || pass "unlisted after remove"
after=$(dbcount)
{ [ "$before" -gt 0 ] && [ "$after" -eq 0 ]; } && pass "databases dropped ($before -> $after)" || fail "databases not dropped ($before -> $after)"

cleanup
echo "=== $fails failure(s) ==="
exit $fails
