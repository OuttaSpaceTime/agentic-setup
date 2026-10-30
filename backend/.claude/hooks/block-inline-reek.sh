#!/usr/bin/env bash
# PreToolUse hook: refuse inline `# :reek:` suppressions in Ruby; they belong in .reek.yml.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

case "$FILE_PATH" in
  *.rb) ;;
  *) exit 0 ;;
esac

CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // .tool_input.content // empty')
echo "$CONTENT" | grep -q ':reek:' || exit 0

jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "No inline `# :reek:` comments. Add `Class#method` to the detector'"'"'s `exclude:` list in .reek.yml instead."
  }
}'
