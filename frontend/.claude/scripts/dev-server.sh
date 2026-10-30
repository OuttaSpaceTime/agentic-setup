#!/bin/sh
# Claude-managed Angular dev server — start or report status.
# Usage: bash .claude/scripts/dev-server.sh
#
# Outputs key=value lines:
#   STATUS=running|started|error
#   PORT=<port>
#   PID=<pid>
#   LOG=<log path>
#   MSG=<human-readable message>

set -e

PROJECT_NAME="vilocify-frontend"
PID_FILE="/tmp/claude-ng-serve-${PROJECT_NAME}.pid"
LOG_FILE="/tmp/claude-ng-serve-${PROJECT_NAME}.log"
PORT_MIN=4201
PORT_MAX=4210
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# --- helper: is this PID still our ng serve? ---
is_our_ng_serve() {
  _pid="$1"
  kill -0 "$_pid" 2>/dev/null || return 1
  if [ -f "/proc/${_pid}/cmdline" ]; then
    _cmd=$(tr '\0' ' ' < "/proc/${_pid}/cmdline" 2>/dev/null)
    case "$_cmd" in
      *ng\ serve*|*ng\ *serve*) return 0 ;;
    esac
  fi
  return 1
}

# --- helper: is a port in use? ---
port_in_use() {
  ss -tln "sport = :$1" 2>/dev/null | grep -q ":$1"
}

# --- check existing tracked server ---
if [ -f "$PID_FILE" ]; then
  TRACKED_PID=$(sed -n '1p' "$PID_FILE")
  TRACKED_PORT=$(sed -n '2p' "$PID_FILE")

  if is_our_ng_serve "$TRACKED_PID"; then
    echo "STATUS=running"
    echo "PORT=${TRACKED_PORT}"
    echo "PID=${TRACKED_PID}"
    echo "LOG=${LOG_FILE}"
    echo "MSG=Dev server already running on port ${TRACKED_PORT} (PID ${TRACKED_PID})"
    exit 0
  else
    rm -f "$PID_FILE"
  fi
fi

# --- find a free port in range ---
CHOSEN_PORT=""
port=$PORT_MIN
while [ "$port" -le "$PORT_MAX" ]; do
  if ! port_in_use "$port"; then
    CHOSEN_PORT="$port"
    break
  fi
  port=$((port + 1))
done

if [ -z "$CHOSEN_PORT" ]; then
  echo "STATUS=error"
  echo "MSG=No free port found in range ${PORT_MIN}-${PORT_MAX}. Orphaned servers are likely holding the range — run 'bash .claude/scripts/dev-server-kill-all.sh' to reap them, then retry."
  exit 1
fi

# --- start ng serve in background ---
cd "$SCRIPT_DIR"
npx ng serve --port "$CHOSEN_PORT" > "$LOG_FILE" 2>&1 &
NG_PID=$!

printf '%s\n%s\n' "$NG_PID" "$CHOSEN_PORT" > "$PID_FILE"

sleep 2

if ! kill -0 "$NG_PID" 2>/dev/null; then
  echo "STATUS=error"
  echo "MSG=ng serve exited immediately. Check ${LOG_FILE}"
  rm -f "$PID_FILE"
  exit 1
fi

echo "STATUS=started"
echo "PORT=${CHOSEN_PORT}"
echo "PID=${NG_PID}"
echo "LOG=${LOG_FILE}"
echo "MSG=Dev server started on port ${CHOSEN_PORT} (PID ${NG_PID}). Tail the log to check compilation."
exit 0
