# Verify the /script-request template

Runs the `.claude/skills/script-request` template against a known-good endpoint
(`GET /api/v2/componentRequests?sort=id` as an org-A admin) to confirm the
in-process request pattern works: expect HTTP 200, no exception.
Run: `bin/rails runner .solve/tasks/2026-07-14-script-request-verify/request.rb`
