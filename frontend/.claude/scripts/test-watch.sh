#!/bin/sh
# Claude-managed Angular test watcher — start or report status.
# Usage: bash .claude/scripts/test-watch.sh <include-pattern> [<include-pattern>...]
#
# Examples:
#   bash .claude/scripts/test-watch.sh 'src/app/features/inbox/**/*.spec.ts'
#   bash .claude/scripts/test-watch.sh 'src/app/features/inbox/**/*.spec.ts' 'src/app/shared/components/card/**/*.spec.ts'
#
# Outputs key=value lines:
#   STATUS=running|started|error
#   PID=<pid>
#   LOG=<log path>
#   INCLUDES=<patterns>
#   MSG=<human-readable message>

set -e

PROJECT_NAME="vilocify-frontend"
PID_FILE="/tmp/claude-ng-test-${PROJECT_NAME}.pid"
LOG_FILE="/tmp/claude-ng-test-${PROJECT_NAME}.log"
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# --- helper: is this PID still our ng test? ---
is_our_ng_test() {
  _pid="$1"
  kill -0 "$_pid" 2>/dev/null || return 1
  if [ -f "/proc/${_pid}/cmdline" ]; then
    _cmd=$(tr '\0' ' ' < "/proc/${_pid}/cmdline" 2>/dev/null)
    case "$_cmd" in
      *ng\ test*|*ng\ *test*) return 0 ;;
    esac
  fi
  return 1
}

# --- check existing tracked watcher ---
if [ -f "$PID_FILE" ]; then
  TRACKED_PID=$(sed -n '1p' "$PID_FILE")
  TRACKED_INCLUDES=$(sed -n '2p' "$PID_FILE")

  if is_our_ng_test "$TRACKED_PID"; then
    echo "STATUS=running"
    echo "PID=${TRACKED_PID}"
    echo "LOG=${LOG_FILE}"
    echo "INCLUDES=${TRACKED_INCLUDES}"
    echo "MSG=Test watcher already running (PID ${TRACKED_PID}). Stop first to change include patterns."
    exit 0
  else
    rm -f "$PID_FILE"
  fi
fi

# --- validate arguments ---
if [ $# -eq 0 ]; then
  echo "STATUS=error"
  echo "MSG=No include patterns provided. Usage: bash .claude/scripts/test-watch.sh '<pattern>' [<pattern>...]"
  exit 1
fi

# --- build --include arguments ---
INCLUDE_ARGS=""
INCLUDE_DISPLAY=""
for pattern in "$@"; do
  INCLUDE_ARGS="${INCLUDE_ARGS} --include=${pattern}"
  if [ -n "$INCLUDE_DISPLAY" ]; then
    INCLUDE_DISPLAY="${INCLUDE_DISPLAY}, ${pattern}"
  else
    INCLUDE_DISPLAY="${pattern}"
  fi
done

# --- start ng test --watch in background ---
cd "$SCRIPT_DIR"
# shellcheck disable=SC2086
npx ng test --watch --browsers=ChromeHeadlessNoSandbox ${INCLUDE_ARGS} > "$LOG_FILE" 2>&1 &
NG_PID=$!

printf '%s\n%s\n' "$NG_PID" "$INCLUDE_DISPLAY" > "$PID_FILE"

sleep 2

if ! kill -0 "$NG_PID" 2>/dev/null; then
  echo "STATUS=error"
  echo "MSG=ng test exited immediately. Check ${LOG_FILE}"
  rm -f "$PID_FILE"
  exit 1
fi

echo "STATUS=started"
echo "PID=${NG_PID}"
echo "LOG=${LOG_FILE}"
echo "INCLUDES=${INCLUDE_DISPLAY}"
echo "MSG=Test watcher started (PID ${NG_PID}). Tail the log to check test results."
exit 0
