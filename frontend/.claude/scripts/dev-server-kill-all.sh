#!/bin/sh
# Kill EVERY Claude/Angular dev server for this project — the big red button
# for when the whole port range (4201-4210) is exhausted by orphaned servers.
#
# Unlike dev-server-stop.sh (which only touches the single PID-file-tracked
# server), this reaps every `ng serve` process regardless of port-binding state
# or which worktree/session started it. Use it when dev-server.sh reports
# "No free port found".
#
# Usage: bash .claude/scripts/dev-server-kill-all.sh
#
# Outputs key=value lines:
#   STATUS=killed|none
#   KILLED=<count>
#   MSG=<human-readable message>

PROJECT_NAME="vilocify-frontend"
PID_FILE="/tmp/claude-ng-serve-${PROJECT_NAME}.pid"
LOG_FILE="/tmp/claude-ng-serve-${PROJECT_NAME}.log"

# --- helper: is this PID an ng serve process? ---
is_ng_serve() {
  _pid="$1"
  [ -f "/proc/${_pid}/cmdline" ] || return 1
  _cmd=$(tr '\0' ' ' < "/proc/${_pid}/cmdline" 2>/dev/null)
  case "$_cmd" in
    *ng\ serve*|*ng\ *serve*) return 0 ;;
  esac
  return 1
}

# --- collect the process groups of every ng serve process ---
PGIDS=""
for pid in $(pgrep -f 'ng serve' 2>/dev/null); do
  is_ng_serve "$pid" || continue
  pgid=$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')
  [ -n "$pgid" ] || continue
  case " $PGIDS " in
    *" $pgid "*) ;;             # already have this group
    *) PGIDS="$PGIDS $pgid" ;;
  esac
done

if [ -z "$PGIDS" ]; then
  rm -f "$PID_FILE"
  echo "STATUS=none"
  echo "KILLED=0"
  echo "MSG=No ng serve processes found. Cleaned up any stale PID file."
  exit 0
fi

# --- terminate each group, escalating to SIGKILL if it lingers ---
COUNT=0
for pgid in $PGIDS; do
  kill -TERM -- -"$pgid" 2>/dev/null && COUNT=$((COUNT + 1))
done

sleep 1

for pgid in $PGIDS; do
  kill -0 -- -"$pgid" 2>/dev/null && kill -9 -- -"$pgid" 2>/dev/null
done

rm -f "$PID_FILE" "$LOG_FILE"

echo "STATUS=killed"
echo "KILLED=${COUNT}"
echo "MSG=Killed ${COUNT} ng serve process group(s) and freed the port range. Run dev-server.sh to start a fresh server."
exit 0
