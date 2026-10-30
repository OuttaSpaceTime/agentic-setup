---
name: feedback_test_description_style
description: No semicolons in test descriptions — use a single plain phrase
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 41e0eea2-1e63-4250-b8e5-3f7cec027b82
  modified: 2026-07-20T08:24:21.443Z
---

Do not use `;` (or other clause-splicing punctuation that signals two assertions) in `test('...')` descriptions. Keep the description as one plain phrase; join clauses with "while"/"and" instead.

**Why:** A semicolon reads as two separate behaviors crammed into one test name, which is noise and hints the test does too much.

**How to apply:** e.g. `'cleanup_due cascades through inbox items and itemables while shared events linger for the sweep'`, not `'...itemables; shared events linger...'`. Relates to [[feedback_test_deletion_pattern]].

Model tests additionally start the description with the method under test: `#` for instance methods, `.` for class methods — e.g. `'#downloadable_by? is true for an admin of the report organization'`. Now also a checked-in project rule in `.claude/rules/310-rails-testing.md`.
