---
name: feedback_isdevmode_over_token
description: Prefer calling isDevMode() directly over the DEVMODE token; how to test isDevMode() code (set/restore global ngDevMode — spyOn fails under esbuild)
metadata: 
  node_type: memory
  type: feedback
  originSessionId: a140e80b-6b68-43ac-9f60-fe12d5fa1548
---

For dev-only gating, Felix prefers calling `isDevMode()` from `@angular/core` directly over injecting the `DEVMODE` token (`@core/services/environment.token`). E.g. an HTTP interceptor uses `if (!isDevMode()) return next(request)`, not `inject(DEVMODE)`. This is consistent with the codebase's other direct callers: `sentry-initializer.ts`, `fake-login.provider.ts`, `rack-mini-profiler.provider.ts`.

**Why:** Simpler, no DI indirection. The `DEVMODE` token is just `factory: () => isDevMode()`; its only real advantage was test-mockability, and that's solvable without it (below).

**How to apply:** To test code that calls `isDevMode()` in this project (Angular 21, esbuild/Karma test build), you **cannot** `spyOn(angularCore, 'isDevMode')` — the ESM export is non-writable, so it throws `isDevMode is not declared writable or has no setter`. Instead drive the global flag it reads. `isDevMode()` is `typeof ngDevMode === 'undefined' || !!ngDevMode`, so:
- Capture `const globalScope = globalThis as unknown as { ngDevMode?: unknown }` and `originalNgDevMode = globalScope.ngDevMode` in `beforeEach`; restore it in `afterEach` (else it leaks into other specs — the full suite shares one browser).
- Set `globalScope.ngDevMode = devMode ? originalNgDevMode : false`. Reuse the original (truthy) value for the dev case — do **not** assign primitive `true`, which clobbers Angular's dev-mode counters object and can throw in strict mode.

The `DEVMODE` token still exists and is the DI seam used by `environment.token.spec.ts` (`{ provide: DEVMODE, useValue: true/false }`) — that's the precedent for the token approach if DI is preferred. Don't waste time re-attempting `spyOn` on module-level `@angular/core` functions here. See [[project_claude_rules]] and [[feedback_present_options]] (this was a decision point I surfaced before acting).
