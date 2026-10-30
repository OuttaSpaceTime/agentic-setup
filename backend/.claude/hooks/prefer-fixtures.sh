#!/usr/bin/env bash
# PostToolUse hook: nudge to reuse fixtures when a test edit builds many records with create!.
# Prefer reassigning an attribute on an existing fixture over building an object graph inline.
# See .claude/rules/312-rails-test-fixtures.md.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only Ruby test files
case "$FILE_PATH" in
  *_test.rb) ;;
  *) exit 0 ;;
esac

# Count create!/create calls in the text just written or edited (the delta, not the whole file)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // .tool_input.content // empty')
CREATE_COUNT=$(echo "$CONTENT" | grep -cE '\.create!?\(')

if [ "$CREATE_COUNT" -ge 3 ]; then
  jq -n --arg n "$CREATE_COUNT" '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": ("This test edit contains " + $n + " create!/create calls. Before building records inline, check test/fixtures/ for a record you can reuse — reassign the differing attribute (membership, organization, timestamp) on an existing fixture instead of constructing a new graph. Use create! only for data that genuinely deviates from fixture state: edge cases, specific counts, item-less/orphaned/aged records. See .claude/rules/312-rails-test-fixtures.md.")
    }
  }'
  exit 0
fi

exit 0
