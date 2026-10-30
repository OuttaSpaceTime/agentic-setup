---
name: frontend-omit-return-types
description: vilocify-frontend (Angular/TS) — omit function/method return types when inferable; rely on inference
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0ba970a0-9410-4944-a7fb-8cba70cb8404
---

In vilocify-frontend (Angular/TypeScript), omit explicit return types whenever TypeScript can infer them — `void`, `boolean`, simple arrays, `string | undefined`, etc. Do NOT add `@typescript-eslint/explicit-function-return-type` or `explicit-module-boundary-types`: enabling them flags ~675 / ~564 existing violations respectively — the repo deliberately relies on inference.

**Why:** Felix's stated convention; the codebase relies on inference, so enabling explicit-return-type rules would break `ng lint` repo-wide.

**How to apply:** Leave return types off inferable functions. Keep an annotation only where it can't be inferred (type predicates like `value is Record<string, unknown>`) or where it validates a constructed domain shape (an object-builder returning `ErrorDetail[]`, since `source: []` would otherwise infer `never[]`). See [[frontend-no-as-cast]].
