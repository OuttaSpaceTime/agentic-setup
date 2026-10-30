---
paths:
  - "test/**/*_test.rb"
---

# Rails Testing Standards

## Make the value under test explicit

When a test asserts on the result of changing an attribute, pass that attribute **explicitly in the request body** and set its **starting value explicitly in setup**. Don't hide the changed field inside a shared params helper, and don't rely on a fixture default for the before-value — the before→after relationship must be readable from the test body alone.

<example type="invalid">

```ruby
# changed field hidden in helper; before-value is an implicit fixture default
patch_api_as(:lindsay_as_admin_in_a, api_v2_subscription_path(id),
  **valid_subscription_patch_params(id: id))
assert_equal(%w[critical major minor informational withdrawn], created_item.priorities_before)  # why all five? reader must know the fixture
```

</example>

<example>

```ruby
# starting value set in setup, changed value explicit in the patch
subscription.update_columns(priorities: %w[major minor])
patch_api_as(:lindsay_as_admin_in_a, api_v2_subscription_path(id),
  params: { data: { id: id, type: 'subscriptions', attributes: { priorities: ['critical'] } } })
assert_equal(%w[major minor], created_item.priorities_before)
assert_equal(%w[critical], created_item.priorities_after)
```

</example>

Shared param helpers (e.g. `valid_subscription_patch_params`) stay fine for tests that do **not** assert on the changed field — auth checks, schema conformance, status codes. Inline the field only when it is the subject of an assertion.

## Assertions must be eyeballable

A reader must see **which** record an assertion is about from the test body alone. A bare count makes them reconstruct fixture arithmetic to learn whether the subject was included.

Shape the setup so the subject is the only candidate, then assert the absolute outcome:

<example type="invalid">

```ruby
# Did the expired-org member get a mail? Unanswerable without counting fixtures
memberships(:expired_org_member).update_attribute!(:expires_at, 2.weeks.from_now)
Task::MembershipExpiriesReminder.send_expiry_reminder_mails!
assert_enqueued_emails(2)
```

</example>

<example>

```ruby
# Subject is the only candidate, so zero means exactly one thing
Membership.unscoped.update_all(expires_at: nil)
memberships(:expired_org_member).update_attribute!(:expires_at, 2.weeks.from_now)
Task::MembershipExpiriesReminder.send_expiry_reminder_mails!
assert_no_enqueued_emails
```

</example>

### Assert the precondition when setup could make the test pass for the wrong reason

<example>

```ruby
# .sole proves the user still HAS a membership, so the exclusion is about the expired org
assert_predicate(users(:iseabal).unscoped_memberships.sole.organization, :expired?)
```

</example>

### Prove a negative test can fail

Re-run it with the fix reverted. An unrelated guard earlier in the method (an early `next` or `return`) can make a negative assertion pass for the wrong reason.

## Time-dependent tests must freeze the clock, not truncate timestamps

A test that writes a timestamp and later asserts on it must run inside `freeze_time` so both evaluations read the same clock. **Never** use `change(usec: 0)`, `to_i`, `round`, or a delta tolerance to make two separately evaluated `Time`-derived values compare equal. Truncating precision only shrinks the flake window instead of closing it — the two `2.days.ago` calls still straddle a second boundary now and then, and the test fails on CI for no reason.

Inside `freeze_time`, `Time.current` already has `usec == 0`, so `change(usec: 0)` is redundant there.

<example type="invalid">

```ruby
# Flaky — `2.days.ago` is evaluated twice against a moving clock; usec truncation hides nothing
component.update_columns(updated_at: 2.days.ago.change(usec: 0))
NotificationPullJob.perform_now(notification)
assert_equal(2.days.ago.change(usec: 0), component.reload.updated_at)
```

</example>

<example>

```ruby
# One clock for the whole test
freeze_time do
  component = create_synced_component(url: '')  # sets updated_at: 2.days.ago
  NotificationPullJob.perform_now(notification)
  assert_equal(2.days.ago, component.reload.updated_at)
end
```

</example>

To advance the clock mid-test, name each instant and `travel_to` the next one. `travel_to` truncates sub-second precision on the instant you hand it, so an instant you also assert against still needs `change(usec: 0)` — that is the one legitimate use:

```ruby
first_sync_time = 2.days.ago.change(usec: 0)
second_sync_time = 1.day.ago.change(usec: 0)
freeze_time(first_sync_time) do
  # ...
  travel_to(second_sync_time)
  # ...
end
```

## Put the test where its subject lives, at the layer it claims

- A test goes through its subject's public entry point. A model test calls the model method
  (`sync_all_later`), not the job that method enqueues; a job test performs the job.
- A generic mechanism gets its own tests instead of a case inside one endpoint's file: keyset
  pagination in a keyset test, request validation pinned once as general behavior ("when X, Y is
  always validated"), not once per controller.
- A model concern gets its own file under `test/models/concerns/` (like `syncable_test.rb`), not
  more cases in a large model test such as `user_test.rb`.
- Use real objects and fixtures. Stub only what the test can't run for real (an external HTTP API);
  a stub on the subject's own collaborators hides the behavior under test.

## Variable Naming

Communicate purpose and matching intent:

<example>

```ruby
matching_request      # will be included in filter results
non_matching_request  # will be excluded
expired_membership
first_active_period, second_active_period
pending_request, completed_request
```

</example>

<example type="invalid">

```ruby
r1, r2, obj, record, result
```

</example>

Only prefix with `_` when the value is truly unused (Rubocop flags useless assignments).

## Project Assertion Helpers (test/support/)

```ruby
# Billing credit setup
add_credits(period, api_credit: 100, component_request_credit: 0)

# Billing assertions
assert_requests_tracked(period, api_credits_used: 1, component_request_credits_used: 0) { ... }
assert_no_requests_tracked(period) { ... }
assert_insufficient_credit_error(:api_request_credit, consumption: { ... }) { ... }
assert_no_credits_enforced(period) { ... }

# Auth
create_api_token_for_membership!(membership)
```

<example type="invalid">

```ruby
# Asserting on fixture values not set in the test
period = billing_consumption_periods(:org_a_period)
Billing::Order.create!(consumption_period: period, api_request_credit: 1000)
assert_equal(2000, period.api_request_usage_meter.total)
# Breaks silently if fixture is changed
```

</example>

<example type="invalid">

```ruby
# Generic variable names
r1 = ComponentRequest.create!(...)
r2 = ComponentRequest.create!(...)
assert_includes(results, r1)  # Which request should be included? Why?
```

</example>
