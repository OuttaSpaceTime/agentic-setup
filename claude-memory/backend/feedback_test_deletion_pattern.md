---
name: Test deletion pattern — destroy! existing fixtures, never update nil
description: Simulate deleted associations by destroying the actual fixture record with destroy!, never by nulling the FK column
type: feedback
originSessionId: 36706804-0b52-4a85-aaad-5387569ca37f
---
Never use `update_column(:fk, nil)` to simulate a deleted association in tests. Instead, destroy the actual record with `destroy!`:

```ruby
# ✅ Destroy the setup actor directly
memberships(:superuser_as_user_in_a).destroy!
@event.reload
assert_match('(deleted)', @item.body)

# ❌ Manually nulling the FK — tests a state that can't happen in production
@event.update_column(:actor_id, nil)
```

Also always use `destroy!` (with bang), never bare `destroy`.

**Fixture reuse rule:** Use existing fixtures — never create records with `Membership.create!` or `User.create!` when a suitable fixture exists. If the test needs to destroy a record to simulate deletion, pick the setup fixture directly (e.g., `memberships(:superuser_as_user_in_a).destroy!`).

**Implication for combined tests:** If a test needs both a "deleted actor" assertion and a "live actor, deleted ML" assertion, these must be **separate tests** — you can't destroy the setup actor and then restore it within the same test. Each test gets fresh fixture state from the transaction rollback.

**Why:** Manually nulling FKs tests a state that can't happen in production (the column goes nil only via DB cascade/nullify). Destroying the actual record tests the real code path and catches missing `dependent:` configurations. Creating temp records adds noise when an existing fixture serves the same purpose.
