---
paths:
  - "test/**/*_test.rb"
---

# OrgScoped Models and Jobs in Tests

## Multi-Tenant in Tests

<example>

```ruby
# .unscoped freely in tests for fixture setup and scope validation
other_org_record = Organization::Group.unscoped.create!(organization: organizations(:org_b), name: 'Other org group')
assert_not_includes(set_current_for(:ansgar_as_user_in_a) { Organization::Group.all.to_a }, other_org_record)
```

</example>

<example>

```ruby
# Current.without_organization_and_membership_scopes for cross-org scenarios
Current.without_organization_and_membership_scopes { Membership.find_by(...) }
```

</example>

### OrgScoped + assert_difference: always use `.unscoped`

`assert_difference` evaluates the count expression before and after the block, both outside any `Current.set` the block opens. If the model has `OrgScoped`, the query gets `WHERE organization_id IS NULL` and reports no change even if rows were created.

<example type="invalid">

```ruby
# Silent failure — OrgScoped filters by nil org after block exits
assert_difference('Inbox::Item.where(membership: subscriber).count', 1) do
  perform_enqueued_jobs
end
```

</example>

<example>

```ruby
# Bypass scope in count assertions
assert_difference('Inbox::Item.unscoped.where(membership: subscriber).count', 1) do
  perform_enqueued_jobs
end
```

</example>

### OrgScoped associations load `nil` outside `Current.set`

The same default scope hides the record behind an association: outside `Current.set`,
`subscription.membership` returns `nil`, so `where(membership: subscription.membership)` becomes
`membership_id IS NULL` and matches nothing. Query by the FK id, or take the record from its fixture
accessor, which bypasses the scope.

<example type="invalid">

```ruby
# subscription.membership is nil here
Inbox::Item.unscoped.where(membership: subscription.membership).count
```

</example>

<example>

```ruby
Inbox::Item.unscoped.where(membership_id: subscription.membership_id).count
```

</example>

To use the association itself, whether you read through it, build a query from it or save through it,
wrap that code, together with any assertion whose scope also needs the bypass, in
`Current.without_organization_and_membership_scopes { }`.

## Asserting + fetching a newly created record

To verify a request creates exactly one record and then assert on its columns, wrap the request in `assert_difference(count, 1)`, then fetch the new row with `order(:created_at).last`.

<example>

```ruby
assert_difference(-> { Inbox::Item::MonitoringList::SubscriptionChanged::Updated.unscoped.count }, 1) do
  patch_api_as(:lindsay_as_admin_in_a, api_v2_subscription_path(id), **params)
end
assert_api_conform(status: 200)

created_item = Inbox::Item::MonitoringList::SubscriptionChanged::Updated.unscoped.order(:created_at).last
assert_equal(%w[critical], created_item.priorities_after)
```

</example>

- **Do NOT** capture ids before the request and diff them afterwards (`existing_ids = …ids` then `where.not(id: existing_ids).sole`). The `assert_difference(count, 1)` already proves exactly one row was created — the diffing is redundant bookkeeping.
- **Use `order(:created_at).last`, never bare `.last`.** Many models use UUID primary keys, where `.last` orders lexicographically by UUID — NOT creation order — and can return a pre-existing fixture row instead of the one the test created. A few models set `implicit_order_column = 'created_at'`, so `.last` happens to work there; `order(:created_at)` works everywhere. Ordering by `created_at` is reliable because fixtures load before the test body runs.
- Don't write a standalone test solely to assert a created record's columns when an existing test already drives the same request and already asserts the creation count. Fold the column assertions into that test instead of duplicating the request setup.

### `perform_enqueued_jobs` + `after_commit` jobs

Jobs enqueued by `after_commit` fire **during the request** (savepoint release). They are in `enqueued_jobs` by the time the request helper returns. Run the request first, then call `perform_enqueued_jobs` (no block):

<example>

```ruby
# Correct order
assert_difference('SomeEvent.unscoped.count', 1) { post_api_as(...) }
assert_api_conform(status: 204)
perform_enqueued_jobs   # now runs jobs that were enqueued by after_commit
```

</example>

<example type="invalid">

```ruby
# Count lacks .unscoped (see "OrgScoped + assert_difference"); the block form itself does run after_commit jobs
perform_enqueued_jobs do
  assert_difference('Inbox::Item.where(membership: s).count', 1) { post_api_as(...) }
end
```

</example>

### Mailer assertions after job execution

`assert_enqueued_emails` and `assert_enqueued_parameterized_email_with` check `enqueued_jobs`, not `deliveries`. After `perform_enqueued_jobs` runs the delivery job (which calls `deliver_later`), the mail job entry remains in `enqueued_jobs` — these assertions still pass.
