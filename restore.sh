#!/usr/bin/env bash
# Copy this snapshot back to where it came from. Clone vilocify-portal and vilocify-frontend into
# ~/Code/Vilocify first; existing files are overwritten, nothing is deleted.
# global/ is a reference snapshot only: chezmoi (~/Code/Misc/master-terminal) restores those files.
# shell/aliases.zsh stays here: ~/.zshrc sources it from ~/Code/Misc/agentic-setup.
# Debug: `set -x` on any line traces every command from there, `set +x` stops; Ruby it runs takes `debugger`.
set -euo pipefail

SRC=$(cd "$(dirname "$0")" && pwd)
TARGET_HOME=${TARGET_HOME:-$HOME}
V=$TARGET_HOME/Code/Vilocify

memory_dir() {
  echo "$TARGET_HOME/.claude/projects/$(printf '%s' "$HOME/Code/Vilocify$1" | sed 's:[/.]:-:g')/memory"
}

restore_repo() {
  local from=$1 to=$2
  [[ -d $to/.git ]] || { echo "ERROR: clone $to first" >&2; exit 1; }
  rsync -a --exclude=git-info-exclude "$from/" "$to/"
  cp "$from/git-info-exclude" "$to/.git/info/exclude"
  echo "restored $to"
}

restore_repo "$SRC/backend" "$V/vilocify-portal"
restore_repo "$SRC/frontend" "$V/vilocify-frontend"

mkdir -p "$V/.bin" "$V/herdr-vilocify"
rsync -a "$SRC/bin/" "$V/.bin/"
rsync -a "$SRC/herdr/" "$V/herdr-vilocify/"
echo "restored $V/.bin and $V/herdr-vilocify"

for pair in backend:/vilocify-portal frontend:/vilocify-frontend shared:; do
  dir=$(memory_dir "${pair#*:}")
  mkdir -p "$dir"
  rsync -a "$SRC/claude-memory/${pair%%:*}/" "$dir/"
  echo "restored $dir"
done

echo "next: chezmoi -S ~/Code/Misc/master-terminal/home apply, then put VILOCIFY_API_TOKEN in ~/.zshrc.local"
