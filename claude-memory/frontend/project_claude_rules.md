---
name: project_claude_rules
description: Claude rules created for vilocify-frontend and rationale for what was included/excluded
type: project
---

Claude rules created at `.claude/rules/` from cursor rules in `.cursor/rules/`:

**Created:**
- `020-typescript-strict-migration.md` — strict-migrate.mjs constraint (project-specific)
- `200-angular-conventions.md` — project structure (core/features/shared), inject(), OnPush, single state observable
- `310-angular-testing.md` — factories from @shared/spec/factories, data-test-id, testing component pattern, interceptor testing with provideHttpClient+withInterceptors
- `800-code-verification.md` — exact verification commands (editorconfig-checker, ng lint, ng build, ChromeHeadlessNoSandbox)

**Excluded (general Angular/TS best practices, not project-specific):**
- angular-guards, angular-directives, angular-pipes, angular-interceptors — functional style is standard Angular 15+
- angular-code-consistency — generic refactoring advice
- typescript-style — general TS patterns Claude already knows

**Fixed:**
- Interceptor testing cursor rule (3003) was WRONG — used old HTTP_INTERCEPTORS class registration. Actual project uses provideHttpClient(withInterceptors([...])) + provideHttpClientTesting(). Fixed in 310-angular-testing.md.

**Updated (2026-04-01) via PR review from Niklas Häusele:**
- `200-angular-conventions.md`: Added required `@Input` rule — mark inputs as `required: true` when component is meaningless without the value
- `310-angular-testing.md`: Strengthened inline-single-test rule — do not wrap a single `it()` in its own `describe`/`beforeEach`; inline the setup; also added inline single-use helper rule

**Why:**
- The cursor rules were also loaded for --no-pager on git commands, but Claude Code Bash tool runs non-interactively so git never opens a pager — rule not needed.
