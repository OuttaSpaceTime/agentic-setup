# vilocify-portal

Rails 8 API backend powering the Vilocify security intelligence platform.

@AGENTS.md

## Commands

| Command | Description |
|---------|-------------|
| `bin/test <edited files>` | Run the tests covering a change and gate its patch coverage (do not pipe the output) |
| `bin/rubocop -A` | Lint and autoformat Ruby |
| `bin/rails db:migrate` | Runs under the local-only `MigrationScopeGuard`, which aborts a migration whose SQL shows an `OrgScoped` or `TlpAmberStrict` default scope silently narrowing the rows, or that references `Current` instead of `::Current` |
| `bin/openapi-diff` | Check bundled OpenAPI specs are current |
| `bin/oasdiff` | Detect breaking API changes vs `origin/main` |
| `bin/redocly-lint` | Validate OpenAPI structure |

## Architecture

```
app/
  controllers/api/v2/   # JSON:API controllers (inherits from Api::V2::BaseController)
  models/               # ActiveRecord models with OrgScoped concern for tenant isolation
  models/concerns/      # Shared model behavior (OrgScoped, Syncable, etc.)
  jobs/                 # Async operations (ActiveJob)
  lib/                  # Utility classes and custom cops
test/
  integration/          # API integration tests
  support/              # Test helpers (api_request_helpers.rb, permission_helpers.rb)
openapi/                # OpenAPI 3 spec source files
```

## Multi-Tenancy

Tenant isolation is handled via `Current` (ActiveSupport::CurrentAttributes) and the `OrgScoped` concern which applies a `default_scope` by `Current.organization`. **This is NOT acts_as_tenant.**

- Default: models automatically scope to `Current.organization`
- To bypass: `Current.without_organization_and_membership_scopes { }`
- Never use `.unscoped` in application code — see `.claude/rules/010-multi-tenant-scoping.md`

## API Authentication

Controllers inherit `authenticate_with_any_method!` from `Api::V2::BaseController` (accepts both Bearer token and session).

Controllers using `only_session_auth_for_internal_endpoints!` reject Bearer tokens entirely — session auth only.

## Before Building

Niklas Häusele maintains this codebase; his conventions override the personal defaults in
`~/.claude/CLAUDE.md`. Before writing code, present the decisions he is likely to have an opinion
on as a short approach note and wait for direction:

- a new data format or file location (e.g. `public/` vs. an internal folder served by a controller)
- hand-rolling something a gem in the `Gemfile` already does
- a new route, controller or top-level class

Treat optional review suggestions (caching, extra checks) as follow-up issues, not additions to
the current MR.

## Key Rules

- `.claude/rules/010-multi-tenant-scoping.md` — unscoped / tenant bypass rules
- `.claude/rules/020-authorization.md` — `visible`/`editable` scopes, `Current.permissions`, restricted (TLP:AMBER:STRICT) records
- `.claude/rules/030-code-style.md` — Rails-native modelling, guard clauses, readable control flow, method ordering
- `.claude/rules/031-no-redundant-conditions.md` — no guards around calls that are already no-ops
- `.claude/rules/035-rails-layering.md` — thin controllers and rich models, concerns, async jobs
- `.claude/rules/050-migrations.md` — generate migrations, schema/data split, pure SQL backfills, no concurrent indexes, run and roll back every migration you write
- `.claude/rules/070-views-and-css.md` — asset helpers, partials and helpers for views, BEM modifiers and CSS variables, look at the page
- `.claude/rules/300-integration-tests.md` — API test request helpers
- `.claude/rules/310-rails-testing.md` — explicit values, eyeballable assertions, frozen clocks, test placement
- `.claude/rules/311-rails-tests-orgscoped-jobs.md` — OrgScoped models, created records and jobs in tests
- `.claude/rules/312-rails-test-fixtures.md` — fixture strategy: reuse, repoint, deliberate deletes
- `.claude/rules/320-migration-tests.md` — `test/local/` is reserved for migration tests and local-only helper tests, nothing else; every data migration gets one; default scopes leak into migrations
- `.claude/rules/800-quality-tools.md` — quality gates (run after every code change)
- `.claude/rules/801-openapi-validation.md` — OpenAPI validation workflow
- `.claude/rules/802-quality-findings.md` — how to report every `bin/quality` finding
- `.claude/rules/900-claude-rules.md` — how to write rules, skills, agents and this file
