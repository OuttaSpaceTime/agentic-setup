---
name: script-request
description: >-
  Generate a throwaway script that fires a REAL authenticated request at a
  vilocify-portal /api/v2 endpoint through the full Rails stack (routing, auth,
  OpenAPI validation, controller, authorization) so you can observe the actual
  HTTP status and body. Use this whenever you need to prove how an endpoint
  behaves for a real request — checking whether a query/sort/filter param is
  accepted or rejected, what status an unauthorized or malformed request
  returns, whether a body validates, or reproducing a reported API response.
  Also use it for any request to exercise an endpoint end-to-end rather than
  reading code or writing a full integration test.
---

# script-request

Fire a real request at a `/api/v2` endpoint and read the actual response. This
runs the **whole stack in-process** via `ActionDispatch::Integration::Session`
inside `bin/rails runner` — no `bin/rails server`, no network, no test file.

## Why in-process instead of curl

The session shares the runner's database **and** `secret_key_base`, so an
`ApiToken` you mint in the same script authenticates. A separate `bin/rails
server` process has a different `secret_key_base`, so `ApiToken.digest` won't
match and the token 401s. Hitting the running server also means cross-process DB
surprises. In-process avoids all of it and still exercises every middleware and
before_action.

## Quick start

1. Copy `scripts/request_template.rb` into a SolveIt task dir, e.g.
   `.solve/tasks/<YYYY-MM-DD>-<name>/request.rb` (with a short `.md`).
2. Edit the four constants at the top: `FIXTURE`, `PATH`, `METHOD`, `BODY`.
3. Run it bare: `bin/rails runner .solve/tasks/<date>-<name>/request.rb`.
4. Read the printed `HTTP <status>`, exception class/message, and body.

The template mints a bearer token, sets the host, subscribes for the exception,
sends the request, and prints status + exception + body.

## The gotchas that make or break this

These are ordered by how much time they cost when missed.

- **`session.host = 'localhost'` is mandatory.** An integration session defaults
  to host `www.example.com`. Dev `config.hosts` (`config/environments/development.rb`)
  only allows `web`, `localhost`, `127.0.0.1`, and the private IP, so
  `ActionDispatch::HostAuthorization` blocks the default host with a **403
  blocked-host HTML page — before routing**. That 403 looks exactly like an
  authorization failure but never reaches your controller. Always set the host.

- **Routes can be camelCase.** JSON:API resources are often mounted with an
  explicit `path:` — e.g. `resources :component_requests, path: 'componentRequests'`.
  `/api/v2/component_requests` is a **404**; the real path is
  `/api/v2/componentRequests`. Grep `config/routes.rb` for the resource before
  guessing the URL.

- **Pick a membership that can actually see the data.** Authentication runs
  first (bearer token), then the controller calls `authorize!` inside the action,
  which raises `Authorization::PermissionError` (**403**) when the `.visible`
  scope collapses to a null relation. `superuser_as_admin_in_a` is an org-A admin
  and has `read:org:*` on most resources, so its `.visible` is `all` — a safe
  default. A `user`-role membership only sees owned/authored/subscribed rows, so
  it can 403 purely for lack of visible data. Roles and their permissions live in
  `app/models/membership/authorization.rb`.

- **Fixtures load into the dev DB with deterministic UUIDs.** Resolve one with
  `Membership.find(ActiveRecord::FixtureSet.identify(:label, :uuid))` inside
  `Current.without_organization_and_membership_scopes { ... }` (the default org
  scope would otherwise hide it). If your dev DB was loaded from a staging dump
  rather than fixtures, use a real membership id instead.

- **The order of gates decides which status you get.** A single request passes
  through them in this order; the first failure wins:

  | Gate | Failure status | Exception |
  |------|----------------|-----------|
  | HostAuthorization middleware | 403 (HTML page) | none — blocked before controller |
  | `authenticate_with_any_method!` (before_action) | 401 | `Authentication::*Error` |
  | `validate_request!` OpenAPI (before_action) | 422 | `OpenapiFirst::RequestInvalidError` |
  | `authorize!` (inside the action) | 403 | `Authorization::PermissionError` |

  So a param that isn't in the endpoint's OpenAPI enum is rejected at **422** by
  `validate_request!` — you never reach the controller or the model's own
  allowlist. Reaching a 403 from `authorize!` means the request already passed
  OpenAPI validation.

- **Capture the exception via the notification, not `session.request.env`.** The
  latter comes back nil. Subscribe to `process_action.action_controller` and read
  `payload[:exception_object]`. Note this only fires if the controller action was
  actually reached — a middleware block (like HostAuthorization) leaves it nil,
  which is itself a useful signal that the failure happened before routing.

## Adapting the template

- **Query/sort/filter checks:** put the param in `PATH`
  (`'/api/v2/subscriptions?sort=membership'`). A 422 `RequestInvalidError` naming
  the allowed enum means the spec forbids it.
- **POST/PATCH:** set `METHOD` and `BODY` to a JSON:API hash
  (`{ data: { type: 'subscriptions', attributes: { ... } } }`). `as: :jsonapi`
  already sets the content type.
- **Multiple endpoints:** wrap the send + print in a loop over an array of paths.
- **Unauthorized/forbidden cases:** to test a 401, drop the `Authorization`
  header; to test a 403, mint the token for a lower-privilege fixture membership.
- **SolveIt:** `bin/rails runner <script>` is allowlisted. Keep the script under
  a `.solve/tasks/<date>-<name>/` dir with a `.md`, and never pass args after the
  script path.
