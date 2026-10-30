---
paths:
  - "test/**/*_test.rb"
  - "test/fixtures/**"
---

# Rails Test Fixtures

**Prefer fixtures by default.** Fixtures represent happy-path data shared across tests and dev; they are the default starting point for any test.

Create records manually only when the test requires data that **deviates** from the fixture state — edge cases, specific counts, error conditions, or scenarios that would corrupt fixture data for other tests.

<example>

```ruby
# Happy path — use fixture directly
test 'returns membership details' do
  membership = memberships(:ansgar_as_user_in_a)
  get_api_as(:ansgar_as_user_in_a, api_v2_membership_path(membership))
  assert_response :ok
end
```

</example>

<example>

```ruby
# Edge case deviating from fixture state — create manually
test 'denies request when api credits exhausted' do
  period = organization.current_consumption_period
  add_credits(period, api_credit: 0)  # Specific zero-credit scenario
  assert_insufficient_credit_error(:api_request_credit, consumption: { 'apiRequestsRemaining' => 0, ... }) do
    get_api_as(api_token, some_path)
  end
end
```

</example>

## Repoint an existing fixture instead of building a graph with `create!`

When a fixture is almost the record you need, reassign the differing attribute (membership, organization, timestamp) inside the test rather than `create!`-ing the whole object graph. A pile of `create!`/`<<` calls that rebuilds associations the fixtures already model is the signal to stop and reuse.

<example type="invalid">

```ruby
# Rebuilds a graph the fixtures already provide
notification_event = Inbox::Event::MonitoringList::Notification.create!(organization: org, ml_name_snapshot: 'Sweep ML')
revision = Inbox::Item::MonitoringList::Notification::Revision.create!(version_range: '[55,55]')
notification_event.notification_revisions << revision
notification_item = Inbox::Item::MonitoringList::Notification.create!(event: notification_event, membership: membership, organization: org)
notification_item.notification_revisions << revision
```

</example>

<example>

```ruby
# Reuse the fixture, repoint only the attribute under test
notification_item = inbox_item_monitoring_list_notifications(:lindsay_active_published)  # already links its event + revision
Current.set(organization: org) { notification_item.update!(membership: membership) }
```

</example>

`create!` stays correct for data that genuinely **deviates** from any fixture: item-less / orphaned / aged records, specific counts, or a clean record built to avoid a fixture's incidental state (e.g. a usage-free membership that cleanup will actually delete).

## Repoint rather than delete — deleting a fixture record fights its foreign keys

To isolate a subject, move it (`update_column(:organization_id, …)`) instead of destroying everything around it. Memberships are referenced by `api_tokens`, `component_requests`, `membership_period_usages`, `subscriptions`, `inbox_items` and `monitoring_list_exports`:

- `delete_all` skips the dependent-destroy chain → `PG::ForeignKeyViolation`
- `destroy` outside `Current.set` can't see its OrgScoped children → same violation

<example type="invalid">

```ruby
# FK violation on api_tokens; needs Current.set + manual child teardown to work at all
users(:ansgar).unscoped_memberships.where.not(id: memberships(:expired_org_member)).delete_all
```

</example>

<example>

```ruby
# Pick a fixture that already has exactly one membership and move it
memberships(:iseabal_as_user_in_a).update_column(:organization_id, organizations(:org_expired).id)
```

</example>

This is for isolating a subject. When the deletion itself is under test, `destroy!` that fixture record
directly — never `update_column(:fk, nil)`, which fakes a state only a DB cascade or nullify produces.
For a membership, destroy it inside `Current.set(organization: membership.organization)` (outside it,
9 of 19 membership fixtures hit `InvalidForeignKey`), and pick one without unarchived period usage:
`superuser_as_admin_in_a`, `ansgar_as_user_in_a` and `expired_user_in_a` can never be destroyed.

## Use `find_or_initialize_by` when layering onto fixture data

```ruby
usage = MembershipPeriodUsage.find_or_initialize_by(
  membership: membership,
  billing_consumption_period: period
)
usage.update!(api_request_count: 42)
```

## Reset state in `setup` only when tests actively mutate shared fixture data

```ruby
setup do
  @membership = memberships(:superuser_as_admin_in_a)
  @organization = @membership.organization
  @api_token = create_api_token_for_membership!(@membership)

  Billing::Order.destroy_all
  Billing::ConsumptionPeriod.update_all(api_request_count: 0, component_request_request_count: 0)
end
```
