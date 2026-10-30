#!/usr/bin/env bash
set -euo pipefail

# create-worktree.sh — create git worktree(s) under ../worktrees/ (sibling to
# the repo) that faithfully mirror the main repo, then (optionally) verify
# lint + tests.
#
# Why this exists: a bare `git worktree add` gives you the source but NOT
# gitignored files like node_modules (~900 MB). Several imports in this repo
# are anchored to the workspace root via tsconfig `baseUrl` (e.g.
# `import { add } from 'node_modules/date-fns/add'`), so they only resolve when
# a `node_modules/` directory exists at the worktree root. Reinstalling per
# worktree is wasteful, so we symlink to the main repo's node_modules instead.
# Branches created here are identical copies of the base, so the dependency
# tree matches and the symlink is safe.
#
# Usage:
#   create-worktree.sh <branch-name> [<branch-name> ...]
#   BASE=develop create-worktree.sh <branch-name>      # base off a different ref
#   VERIFY=0 create-worktree.sh <branch-name>          # skip lint + tests
#   create-worktree.sh repair <worktree-path>          # set up an existing worktree
#                                                      # (herdr's worktree.created hook)
#
# Env:
#   BASE    base branch/ref for new branches (default: main)
#   VERIFY  1 = run `ng lint` + `ng test` after creation (default: 1)

BASE="${BASE:-main}"
VERIFY="${VERIFY:-1}"

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <branch-name> [<branch-name> ...]" >&2
  exit 2
fi

# Locate the main working tree (it holds the real node_modules). The shared
# .git lives at --git-common-dir; the main repo root is its parent directory.
COMMON_GIT=$(git rev-parse --git-common-dir)
MAIN_REPO=$(cd "$(dirname "$COMMON_GIT")" && pwd)
# Worktrees live in herdr's layout, <worktrees>/<repo>/<branch>, next to the backend
# ones, e.g. /home/felix/Code/Vilocify/worktrees/vilocify-frontend/<name>.
WORKTREE_ROOT="$(dirname "$MAIN_REPO")/worktrees/vilocify-frontend"

if [ ! -d "$MAIN_REPO/node_modules" ]; then
  echo "error: $MAIN_REPO/node_modules not found — run 'npm install' in the main repo first" >&2
  exit 1
fi

mkdir -p "$WORKTREE_ROOT"

create_one() {
  local name="$1"
  local dest="$WORKTREE_ROOT/$name"

  if [ -e "$dest" ]; then
    echo "==> Worktree already exists, skipping create: $dest"
  else
    echo "==> Creating worktree: $name (base: $BASE)"
    if git -C "$MAIN_REPO" show-ref --verify --quiet "refs/heads/$name"; then
      # Branch already exists — attach it to a new worktree (no -b).
      git -C "$MAIN_REPO" worktree add "$dest" "$name"
    else
      git -C "$MAIN_REPO" worktree add "$dest" -b "$name" "$BASE"
    fi
  fi

  setup_one "$dest"
}

setup_one() {
  local dest="$1"

  # Absolute symlink so it works regardless of how deeply the branch name nests.
  if [ ! -e "$dest/node_modules" ]; then
    ln -s "$MAIN_REPO/node_modules" "$dest/node_modules"
  fi
  echo "    node_modules -> $(readlink "$dest/node_modules")"

  # .claude/ is gitignored, so a fresh worktree has none of it — no rules, no
  # scripts/dev-server.sh (which the verification rules depend on), no skills,
  # no settings. Symlink it to the main repo's so rule and hook changes reach
  # every worktree at once instead of drifting in per-worktree copies.
  if [ -d "$MAIN_REPO/.claude" ]; then
    rm -rf "$dest/.claude"
    ln -sfn "$MAIN_REPO/.claude" "$dest/.claude"
    echo "    linked .claude/ -> $MAIN_REPO/.claude"
  fi

  # .editorconfig-checker.json is locally gitignored (excludes the generated
  # src/readme-oss.html from the editorconfig check) — copy it too, same
  # reason as .claude/ above.
  if [ -f "$MAIN_REPO/.editorconfig-checker.json" ]; then
    cp "$MAIN_REPO/.editorconfig-checker.json" "$dest/.editorconfig-checker.json"
    echo "    copied .editorconfig-checker.json"
  fi
}

verify_one() {
  local name="$1"
  local dest="$WORKTREE_ROOT/$name"
  echo "==> Verifying ($name): ng lint"
  ( cd "$dest" && npx ng lint )
  echo "==> Verifying ($name): ng test"
  ( cd "$dest" && npx ng test --watch=false --browsers=ChromeHeadlessNoSandbox )
}

if [ "$1" = "repair" ]; then
  setup_one "$2"
  exit 0
fi

for name in "$@"; do
  create_one "$name"
done

if [ "$VERIFY" = "1" ]; then
  for name in "$@"; do
    verify_one "$name"
  done
fi

echo "==> Done. Worktrees:"
git -C "$MAIN_REPO" worktree list
