#!/bin/sh
# Stop a Claude-managed Angular dev server.
# Usage: bash .claude/scripts/dev-server-stop.sh
#
# Only kills the process started by dev-server.sh (tracked by PID file).
# Never kills other ng serve processes.
#
# Outputs key=value lines:
#   STATUS=stopped|not_running|error
#   MSG=<human-readable message>

PROJECT_NAME="vilocify-frontend"
PID_FILE="/tmp/claude-ng-serve-${PROJECT_NAME}.pid"
LOG_FILE="/tmp/claude-ng-serve-${PROJECT_NAME}.log"

if [ ! -f "$PID_FILE" ]; then
  echo "STATUS=not_running"
  echo "MSG=No tracked dev server found (PID file does not exist)"
  exit 0
fi

TRACKED_PID=$(sed -n '1p' "$PID_FILE")
TRACKED_PORT=$(sed -n '2p' "$PID_FILE")

# Validate this is still our process before killing
if kill -0 "$TRACKED_PID" 2>/dev/null && [ -f "/proc/${TRACKED_PID}/cmdline" ]; then
  CMD=$(tr '\0' ' ' < "/proc/${TRACKED_PID}/cmdline" 2>/dev/null)
  case "$CMD" in
    *ng\ serve*|*ng\ *serve*)
      # Kill the entire process group (npx -> sh -> ng serve -> esbuild)
      kill -- -"$TRACKED_PID" 2>/dev/null
      sleep 1
      if kill -0 "$TRACKED_PID" 2>/dev/null; then
        kill -9 -- -"$TRACKED_PID" 2>/dev/null
      fi
      rm -f "$PID_FILE" "$LOG_FILE"
      echo "STATUS=stopped"
      echo "PORT=${TRACKED_PORT}"
      echo "PID=${TRACKED_PID}"
      echo "MSG=Dev server on port ${TRACKED_PORT} (PID ${TRACKED_PID}) stopped"
      exit 0
      ;;
  esac
fi

# PID is dead or not our process — just clean up
rm -f "$PID_FILE" "$LOG_FILE"
echo "STATUS=not_running"
echo "MSG=Tracked PID ${TRACKED_PID} is no longer an ng serve process. Cleaned up stale PID file."
exit 0
