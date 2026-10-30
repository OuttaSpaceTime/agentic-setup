---
name: feedback-editorconfig-bin-wrapper-only
description: "run editorconfig only via bin/editorconfig-checker, never npx editorconfig-checker"
metadata:
  node_type: memory
  type: feedback
  originSessionId: d44d5c81-5cd1-49db-963e-faf66c5f4d50
  modified: 2026-10-26T18:26:42.797Z
---

Run editorconfig only through `bin/editorconfig-checker` (what CI and lefthook use), never `npx editorconfig-checker` directly.

**Why:** the bare npx call skips the wrapper's `-exclude`, so it flags the generated `public/openapi/{internal,v2}.yml` bundles (115 false errors on 2026-10-26) while the CI wrapper passes.

**How to apply:** rule 800 no longer lists an editorconfig step (lefthook pre-commit runs it). For a single file, `bin/editorconfig-checker <path>`. Project `.claude/settings.json` denies `Bash(npx editorconfig-checker:*)`; the global allow entry stays for the frontend repo.
