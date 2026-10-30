# Does the API forbid `sort=membership` on a REAL request?

`membership` is NOT in either sort enum in the spec (OpenapiFirst validates every
request), but IS in `orderable_columns` in the code. Auth runs before OpenAPI
validation (`base_controller.rb:4` before `:6`), so a real probe needs a token.

## 02-real-request-sort-membership.rb
Mints an ApiToken for an existing DEV-DB membership, then issues a real HTTP request
(`sort=membership`) through the full stack against both endpoints; prints status+body.
Run: `bin/rails runner .solve/tasks/2026-07-14-membership-sort-allowed/02-real-request-sort-membership.rb`
- HTTP 400 => spec forbids it (what Felix wants). HTTP 200 => silently accepted.
Needs the dev DB to have >=1 Membership.
