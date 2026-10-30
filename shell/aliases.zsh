# Sourced from ~/.zshrc. vilocify() needs VILOCIFY_API_TOKEN exported there.

mkcd ()
{
    mkdir -p -- "$1" &&
       cd -P -- "$1"
}

# Percent-encode a single value for safe use in URL credentials.
enc() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

function rebase-onto {
  commit=$(git log --oneline | fzf --prompt 'Select the first commit you want to move' | awk '{print $1}')
  branch=$(git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads/ | fzf --prompt 'Select the branch to rebase onto' | awk '{print $1}')
  test_command="git rebase -i --onto $branch $commit~"
  read -p "Execute command '$test_command' (Y/n)? " choice
  case "$choice" in
    n|N ) echo "aborted.";;
    * ) eval "$test_command";;
  esac
}

gcol() {
  local branch
  branch=$(git for-each-ref --format='%(refname:short)' refs/heads/ | fzf --prompt 'branch> ') || return
  git checkout "$branch"
}

# Override the Oh My Zsh git alias with a branch picker.
unalias gcor 2>/dev/null
gcor() {
  local remote branch
  remote=$(git for-each-ref --format='%(refname:short)' refs/remotes/origin | grep -v '^origin/HEAD$' | fzf --prompt 'remote branch> ') || return
  branch=${remote#origin/}

  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git switch "$branch"
  else
    git switch --track -c "$branch" "$remote"
  fi
}

gbr() {
  local branches
  branches=$(git branch --format='%(refname:short)' | fzf -m --prompt 'delete branch> ') || return
  echo "$branches" | xargs -r git branch -D
}

gwr() {
  local main selection
  main=$(git worktree list | head -1 | awk '{print $1}')
  selection=$(git worktree list | awk '{n=split($1,a,"/"); print a[n]"\t"$1}' \
    | fzf -m --with-nth=1 --delimiter='\t' --prompt 'remove worktree> ') || return
  echo "$selection" | cut -f2 | xargs -r -I{} git -C "$main" worktree remove --force {}
  [[ -d $PWD ]] || cd "$main"

  # Sweep orphaned per-worktree databases — vilocify-portal only.
  [[ "$main" == "$HOME/Code/Vilocify/vilocify-portal" ]] || return
  local live orphans db base
  live=$(git worktree list | awk 'NR>1{print $1}' | while read -r wt; do
    printf '%s_%s\n' \
      "$(basename "$wt" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9]/_/g' | cut -c1-20)" \
      "$(printf '%s' "$wt" | md5sum | cut -c1-6)"
  done)
  orphans=$(PGPASSWORD=password psql -h localhost -p 5433 -U postgres -Atc \
    "select datname from pg_database where datname ~ '^vilocify_portal_(dev|test)_.+_[0-9a-f]{6}(_[0-9]+)?\$' order by datname" \
    | while read -r db; do
        base=$(printf '%s' "$db" | sed -E 's/^vilocify_portal_(dev|test)_//; s/^(.+_[0-9a-f]{6})(_[0-9]+)?$/\1/')
        grep -qxF "$base" <<< "$live" || echo "$db"
      done)
  [[ -z "$orphans" ]] && return
  while read -r db; do
    PGPASSWORD=password psql -h localhost -p 5433 -U postgres -c \
      "drop database if exists \"$db\" with (force)" >/dev/null
  done <<< "$orphans"
  echo "gwr: dropped $(grep -c . <<< "$orphans") orphan databases."
}

alias gpo='git push origin'
alias gpod='git push origin -d'
alias ga='git add'
alias gcmsg='git commit -m'
alias gcmsge='git commit --allow-empty -m'
alias gcmsgem='git commit --allow-empty-message -m'
git() {
  if [[ "$1" == commit ]] && (( ${@[(I)--amend]} )); then
    echo "git commit --amend is blocked. Make a new commit instead." >&2
    return 1
  fi
  command git "$@"
}
alias killrails='lsof -t -i :3000 -s TCP:LISTEN | xargs kill -9'
alias newrails='killrails 2>/dev/null; pkill -9 -f -F tmp/pids/server.pid puma 2>/dev/null; rm -f tmp/pids/server.pid; bin/rails server'
alias killng='fuser -k 4200/tcp'
alias newng='killng 2>/dev/null; npx ng serve'
alias fixup='git log --oneline | fzf | awk '\''{print $1}'\'' | xargs -I '\''{}'\'' git commit --fixup {}'
alias merge-conflicts='git diff --name-status --diff-filter=U'
alias dew='docker compose exec web'
alias de='docker compose exec'
alias vilcb='cd ~/Code/Vilocify/vilocify-portal'
alias vilcf='cd ~/Code/Vilocify/vilocify-frontend'
vilcw() {
  local base=~/Code/Vilocify/worktrees dir
  dir=$(find "$base" -mindepth 2 -maxdepth 2 -type d ! -name '.*' -printf '%P\n' | sort | fzf) && cd "$base/$dir"
}
alias study='cd ~/Code/Misc/study'
alias master='cd ~/Code/Misc/master-terminal'
alias cpdrive='rclone copy drive:Documents/'Independent Order Of Light Warriors' ~/Code/Misc/prana-power/vault'
alias syncdrive='rclone sync --interactive ~/Code/Misc/prana-power/vault drive:Documents/'Independent''
alias synclocal='rclone sync --interactive drive:Documents/'Independent' ~/Code/Misc/prana-power/vault'
alias claude-review='SOLVEIT_OFF=1 claude --settings '\''{"outputStyle":"default"}'\'' --mcp-config ~/Code/Misc/agentic-channels/code-review/standalone.mcp.json'
alias claude-forge='SOLVEIT_OFF=1 claude --settings '\''{"outputStyle":"default"}'\'' --mcp-config ~/Code/Misc/agentic-channels/forge/standalone.mcp.json'
alias claude-all='SOLVEIT_OFF=1 claude --settings '\''{"outputStyle":"default"}'\'' --append-system-prompt '\''Before running git add, commit, or push: show a summary listing every changed file with a one-line reason it changed, and a suggested single-line commit message. Wait for the human to confirm before staging, committing, and pushing.'\'''

# Per-session claude model + reasoning effort (avoids global /model bleed across instances)
alias clo='claude --model opus'
alias cls='claude --model sonnet'
alias clol='claude --model opus --effort low'
alias clom='claude --model opus --effort medium'
alias cloh='claude --model opus --effort high'
alias clox='claude --model opus --effort xhigh'
alias clsl='claude --model sonnet --effort low'
alias clsm='claude --model sonnet --effort medium'
alias clsh='claude --model sonnet --effort high'
alias clsx='claude --model sonnet --effort xhigh'

function nvim-listen() {
  local socket_dir root escaped_root socket
  socket_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
  socket_dir="${socket_dir%/}"
  root=$(git rev-parse --show-toplevel 2>/dev/null) || root="$PWD"
  escaped_root="${root//\//%}"
  socket=$(mktemp -u "$socket_dir/nvim-mcp.${escaped_root}.XXXXXX.sock")

  export NVIM_LISTEN_ADDRESS="$socket"
  echo "nvim-listen: $socket" >&2
  command nvim --listen "$socket" "$@"
}

function claude() {
  # Keep the current project authorized before starting Claude.
  direnv allow . >/dev/null 2>&1 || true

  command claude "$@"
}

vilocify() {
  curl -H "Authorization: Bearer ${VILOCIFY_API_TOKEN}" -H 'Accept: application/vnd.api+json' "localhost:3000/api/v2$1"
}
