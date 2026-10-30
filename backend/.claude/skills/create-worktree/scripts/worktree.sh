#!/usr/bin/env bash
# Usage:
#   worktree.sh create <branch> [start-point] [extra-file...]
#   worktree.sh repair <worktree-path>
#   worktree.sh remove <branch>
set -euo pipefail

MAIN="$HOME/Code/Vilocify/vilocify-portal"
WORKTREES="$HOME/Code/Vilocify/worktrees/vilocify-portal"
PG=vilocifyportal-postgres-1
CONFIG_FILES=(
  .env
  .env.development.local
  .env.test.local
  bin/quality
  config/initializers/fixture_console_helpers.rb
  config/initializers/scope_console_helpers.rb
  config/initializers/migration_scope_guard.rb
  test/local/migration_scope_guard_test.rb
)
_link_claude() {
  local wt="$1"
  rm -rf "$wt/.claude"
  ln -sfn "$MAIN/.claude" "$wt/.claude"
  ln -sfn "$MAIN/CLAUDE.md" "$wt/CLAUDE.md"
  ln -sfn "$MAIN/bin/test" "$wt/bin/test"
  ln -sfn "$MAIN/.simplecov" "$wt/.simplecov"
  mkdir -p "$wt/.solve"
  ln -sfn "$MAIN/.solve/scripts" "$wt/.solve/scripts"
}

_copy_config() {
  local wt="$1" f
  for f in "${CONFIG_FILES[@]}"; do
    [ -f "$MAIN/$f" ] && mkdir -p "$(dirname "$wt/$f")" && cp -p "$MAIN/$f" "$wt/$f"
  done
}

_npm_ci() {
  ( cd "$1" && { npm ci || { echo "npm ci failed, falling back to npm install" >&2; npm install; }; } )
}

_suffix() {
  local wt="${1%/}" slug
  slug="$(basename "$wt" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9]/_/g' | cut -c1-20)"
  printf '%s_%s' "$slug" "$(printf '%s' "$wt" | md5sum | cut -c1-6)"
}

_isolate_db() {
  local wt="$1" suffix
  suffix="$(_suffix "$wt")"
  ( cd "$wt"
    git update-index --no-skip-worktree config/database.yml 2>/dev/null || true
    git checkout -- config/database.yml
    sed -i -E \
      -e "s/^( *database: vilocify_portal_dev).*\$/\1_${suffix}/" \
      -e "s/^( *database: vilocify_portal_test).*\$/\1_${suffix}/" \
      config/database.yml
    git update-index --skip-worktree config/database.yml
    bin/rails db:prepare
    bin/rails db:fixtures:load )
}

_copy_coverage() {
  local wt="$1"
  [ -f "$MAIN/coverage/map/coverage.json" ] || {
    echo "WARN: $MAIN/coverage/map/coverage.json missing - run bin/test in the main repo to seed it" >&2
    return 0
  }
  rm -rf "$wt/coverage"
  cp -rp "$MAIN/coverage" "$wt/coverage"
}

_rebuild_test_map() {
  local wt="$1"
  [ -x "$wt/bin/test" ] || return 0
  mkdir -p "$wt/tmp"
  ( cd "$wt" && nohup ./bin/test >tmp/test-map-rebuild.log 2>&1 & )
  echo "--- test map ---"
  echo "seeded from main, whole-suite rebuild running in background: tail -f $wt/tmp/test-map-rebuild.log"
}

_verify() {
  local wt="$1"
  ( cd "$wt"
    echo "--- git status (blank = clean) ---"; git status --porcelain
    echo "--- rules main=$(ls "$MAIN/.claude/rules/" | wc -l) worktree=$(ls .claude/rules/ | wc -l) ---"
    echo "--- redocly ---"; npx --no-install redocly --version 2>&1 | tail -1 || true
    echo "--- rails ---"; bin/rails runner 'puts "Rails OK: #{Rails.env}"' 2>&1 | head -3 || true
    echo "--- db names ---"; grep -E 'database: vilocify_portal_(dev|test)' config/database.yml || true
    echo "--- reek ---"
    if [ -x bin/reek ]; then
      bundle exec reek $(git ls-files --cached --others --exclude-standard -- 'app/*.rb' 'lib/*.rb' 'config/*.rb' 'test/*.rb') \
        >/dev/null 2>&1 && echo "reek OK: 0 warnings" || echo "reek: warnings outstanding"
    else
      echo "reek n/a (branch predates bin/reek)"
    fi )
}

cmd_create() {
  local branch="${1:?branch required}" start="${2:-}"
  shift $(( $# < 2 ? $# : 2 ))
  local wt="$WORKTREES/$branch" extra
  mkdir -p "$WORKTREES"
  [ -e "$wt" ] && { echo "ERROR: $wt already exists" >&2; exit 1; }
  if git -C "$MAIN" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$MAIN" worktree add "$wt" "$branch"
  else
    [ -n "$start" ] || { echo "ERROR: new branch '$branch' needs a start-point" >&2; exit 1; }
    git -C "$MAIN" worktree add -b "$branch" "$wt" "$start"
  fi
  _link_claude "$wt"; _copy_config "$wt"; _npm_ci "$wt"; _isolate_db "$wt"; _copy_coverage "$wt"
  for extra in "$@"; do
    cp -r "$MAIN/$extra" "$wt/" || echo "WARN: extra '$extra' not matched" >&2
  done
  _verify "$wt"; _rebuild_test_map "$wt"
}

cmd_repair() {
  local wt="${1:?worktree-path required}"
  [ -f "$wt/.git" ] || { echo "ERROR: $wt is not a git worktree" >&2; exit 1; }
  _link_claude "$wt"; _copy_config "$wt"; _npm_ci "$wt"; _isolate_db "$wt"; _copy_coverage "$wt"
  _verify "$wt"; _rebuild_test_map "$wt"
}

cmd_remove() {
  local branch="${1:?branch required}" wt suffix
  wt="$WORKTREES/$branch"
  suffix="$(_suffix "$wt")"
  git -C "$MAIN" worktree remove "$wt"
  docker exec "$PG" psql -U postgres -tAc \
    "SELECT 'DROP DATABASE IF EXISTS \"'||datname||'\" WITH (FORCE);' FROM pg_database WHERE datname LIKE 'vilocify_portal_%${suffix}%'" \
    | { grep . || true; } | docker exec -i "$PG" psql -U postgres
}

main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    create) cmd_create "$@" ;;
    repair) cmd_repair "$@" ;;
    remove) cmd_remove "$@" ;;
    *) echo "Usage: worktree.sh create|repair|remove ..." >&2; exit 2 ;;
  esac
}
main "$@"
