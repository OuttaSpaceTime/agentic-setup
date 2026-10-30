---
name: belongs_to namespace defaults over explicit class_name/foreign_key
description: When the association name matches a class reachable via Rails constant lookup AND the FK column follows convention, drop class_name/foreign_key/inverse_of: false and let Rails resolve. Applies to STI subclasses pointing at the STI parent.
type: feedback
originSessionId: 75f8c72b-304f-4880-a06e-3c5ac602e40f
---
When writing `belongs_to` on a namespaced model, prefer the bare form over explicit overrides:

```ruby
# ✅ bare — Rails namespace lookup resolves the class, FK convention provides the column
class MonitoringList::SubscriptionChangedItem < ApplicationRecord
  belongs_to(:subscription_changed_event)   # → MonitoringList::SubscriptionChangedEvent (STI parent), FK subscription_changed_event_id
end

# ❌ noisy — only needed when one of the conventions doesn't hold
belongs_to(
  :event,
  class_name: 'MonitoringList::SubscriptionChangedEvent::AddedEvent',
  foreign_key: 'subscription_changed_event_id',
  inverse_of: false
)
```

**Why:** Rails constant lookup from inside `MonitoringList::SubscriptionChangedItem` finds `MonitoringList::SubscriptionChangedEvent` from the bare `:subscription_changed_event` name. Default FK convention is `{association_name}_id` which matches. With STI on the target, runtime dispatch handles the subclass — pinning `class_name:` to a specific child is wrong anyway (each item child would only accept its matching event child).

`inverse_of: false` is also unnecessary in the default case — only Rubocop's `Rails/InverseOf` cop demands it when something about the association is non-conventional.

**How to apply:**
- For STI items pointing at STI events: hoist the single `belongs_to(:event_name)` to the **STI parent** (mirrors `DependenciesChangedItem` → `:event` pattern). Children never redeclare it.
- The FK column name should be `{association_name}_id`. If you're free to pick the column name, pick the descriptive one that matches the association.
- Fixture key for the association uses the association name (`subscription_changed_event: added_one`), not the column name.
- When passing the association in `.new`, use the association name (`subscription_changed_event: event`) — not `event: event` after a rename.
