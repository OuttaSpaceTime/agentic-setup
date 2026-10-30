# Validate cursor pagination links change

Runs the project quality/OpenAPI gates after changing:
- app/controllers/concerns/api_serialization.rb (Array-branch links -> first/next only)
- openapi/paths/inboxItems.yml (index links $ref -> cursorPaginationLinks.yml)

Scripts:
- 01-rubocop.sh — rubocop -A on the two changed files
- 02-tests.sh — inbox items controller integration test (no pipe)
- 03-openapi-diff.sh — check bundled specs current
- 04-lint.sh — action_json_api:lint
