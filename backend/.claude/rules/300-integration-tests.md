---
paths:
  - "test/integration/**/*_test.rb"
---

# Integration Test Request Helpers

## Default: use `*_api_as` helpers

For endpoints using default `authenticate_with_any_method!` auth, always use helpers from
`test/support/api_request_helpers.rb`. They handle `Content-Type`, `as: :jsonapi`, and auth — no `sign_in_fixture` needed.

<example>

```ruby
get_api_as(:ansgar_as_user_in_a, api_v2_monitoring_lists_path)
post_api_as(:ansgar_as_user_in_a, api_v2_monitoring_lists_path, params: { data: { ... } })
patch_api_as(:ansgar_as_user_in_a, api_v2_monitoring_list_path(id), params: { data: { ... } })
delete_api_as(:ansgar_as_user_in_a, api_v2_monitoring_list_path(id))
```

</example>

Helpers accept either a membership fixture symbol that has a matching `<label>_token` entry in `test/fixtures/api_tokens.yml`, or an `ApiToken` record.

## Session-only endpoints: `sign_in_fixture` + raw verb

Controllers with `only_session_auth_for_internal_endpoints!` reject Bearer tokens. Use session auth:

<example>

```ruby
sign_in_fixture(:ansgar_as_user_in_a)
post(api_v2_some_path, params: { ... }, as: :jsonapi, **content_type_header)
```

</example>

## `with_permissions`

`with_permissions(*perms)` replaces the role's entire permission set with only what is listed, and raises
on an unknown permission string. It stubs `Current.permissions`, so it works with either auth pattern.

Name the test after the permission it proves, and show both sides of the boundary in it:

<example>

```ruby
test('write:ml_owned:subscriptions permission is required to create subscriptions') do
  with_permissions([]) { post_api_as(:ansgar_as_user_in_a, api_v2_subscriptions_path, **valid_subscription_params) }
  assert_api_conform(status: 403)

  with_permissions('write:ml_owned:subscriptions', 'read:owned:monitoring_lists', 'read:org:memberships') do
    post_api_as(:ansgar_as_user_in_a, api_v2_subscriptions_path, **valid_subscription_params)
  end
  assert_api_conform(status: 201)
end
```

</example>

Use `... is sufficient to ...` for a test proving that one permission alone grants access.

## Unauthenticated / partial-session assertions

```ruby
# no session, no token → 401
post(path, params: params, as: :jsonapi, **content_type_header)

# partial session (no membership selected) → 401
partially_sign_in_user(:superuser)
post(path, params: params, as: :jsonapi, **content_type_header)
```

<example type="invalid">

```ruby
# Using sign_in_fixture for token-accepting endpoints
sign_in_fixture(:ansgar_as_user_in_a)
get(api_v2_monitoring_lists_path, as: :jsonapi, **content_type_header)
```

</example>
