---
name: feedback_reek_no_inline_comments
description: "Suppress reek warnings via detector exclude entries in .reek.yml, never inline `# :reek:Smell` comments"
metadata:
  node_type: memory
  type: feedback
  originSessionId: ab7bdd82-28e3-4d40-a70d-4a2ce2bf7220
  modified: 2026-10-23T09:48:08.593Z
---

To silence a reek warning in tracked code, add `Class#method` to that detector's `exclude:` list in `.reek.yml` (optionally with a one-line `#` reason above it, like the existing test-helper entries). Never put `# :reek:SmellName` comments in the source.

**Why:** user rejected inline `:reek:` comments on 2026-10-23 ("do not use inline comment add to ignore file"); the codebase has zero `:reek:` comments, `.reek.yml` is the single place suppressions live — same stance as no inline RuboCop disables ([[feedback_rubocop_disable]]).

**How to apply:** detector-level `exclude:` entries are fine; `exclude_paths` for local-only files is still banned ([[project_reek_local_file_exclusion]]). When inserting with sed, match the detector block — the same `Class#method` line often appears under several detectors (e.g. BooleanParameter and UtilityFunction), so a global substitution adds stray entries.
