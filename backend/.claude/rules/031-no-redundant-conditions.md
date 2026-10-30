---
paths:
  - "**/*.rb"
---

# No Redundant Conditions

Do not guard a call that is already a no-op on empty or nil input. Verified no-ops in this codebase
(Rails 8.1.3.1) — none of these need a preceding `return if …empty?`:

| Call | Empty/nil behavior |
|------|--------------------|
| `[].each`, `[].map`, `[].sum`, `[].each_slice(n)` | no iteration, `[]` / `0` |
| `relation.find_each` on an empty relation | no iteration, no SQL |
| `relation.pluck(:id)` on `where(id: [])` | `[]`, no SQL |
| `Model.insert_all([])` | no INSERT issued |
| `relation.destroy_all` / `update_all` / `delete_all` on empty | `[]` / `0`, one harmless `1=0` query |
| `Array.wrap(nil)`, `nil.to_a`, `nil.to_h` | `[]` / `{}` |
| `[].include?(x)`, `Model.none.exists?` | `false` |

Keep a guard only when it changes behavior — it prevents creating a record, raising, logging,
an expensive query, or a network call.

<example type="invalid">

```ruby
def link_revisions(rows)
  return if rows.empty?

  Inbox::Item::MonitoringList::Notification::RevisionLink.insert_all(rows)
end

def notify(memberships)
  return if memberships.empty?

  memberships.each { |membership| membership.notify_later }
end

def names(components)
  return [] if components.blank?

  components.map(&:name)
end
```

</example>

<example>

```ruby
def link_revisions(rows)
  Inbox::Item::MonitoringList::Notification::RevisionLink.insert_all(rows)
end

def notify(memberships)
  memberships.each { |membership| membership.notify_later }
end

def names(components)
  components.map(&:name)
end

def track_dependency_removal(removed_child_ids)
  return if removed_child_ids.empty?

  Inbox::Event::MonitoringList::DependenciesChanged::Removed.create!(
    organization: Current.organization,
    child_ids: removed_child_ids
  )
end
```

</example>

Same rule for nil: do not pre-check a value the callee already handles.

<example type="invalid">

```ruby
membership.email.presence ? membership.email.strip : nil
if params[:ids].nil?
  ids = []
else
  ids = params[:ids]
end
```

</example>

<example>

```ruby
membership.email&.strip
ids = Array.wrap(params[:ids])
```

</example>

Do not rewrite guards in code you were not asked to change. This rule governs code you are writing;
removing an existing guard is a separate, deliberate change.

<critical>

  - Never add a condition whose only effect is skipping a call that is already a no-op.

</critical>
