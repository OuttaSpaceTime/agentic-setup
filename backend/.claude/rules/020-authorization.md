---
paths:
  - "app/**/*.rb"
---

# Authorization: Role Permissions and Restricted Records

## Context

Two boundaries guard every read and write, and they meet in the `visible` / `editable` scopes:

1. **Role permissions** — `Current.permissions` is the permission-string list derived from the
   membership's role (`Membership::Authorization::ROLE_PERMISSIONS`).
2. **TLP:AMBER:STRICT restriction** — the `TlpAmberStrict` concern (`Component`, `Notification`)
   adds a second `default_scope` on top of `OrgScoped`.

Tenant isolation itself is covered by `.claude/rules/010-multi-tenant-scoping.md`.

## Requirements

### `visible` / `editable` are the boundary

Every authorizable model exposes a `visible` scope (reads) and, where writes exist, an `editable`
scope. They branch on `Current.permissions` and return `none` when nothing is permitted — never
`all`. Defined on `MonitoringList`, `ComponentRequest`, `Subscription`, `Component`, `Notification`,
`Notification::Vulnerability`, `Membership`.

Build new read paths on `visible`. Never re-implement a permission check in a controller, serializer,
job, or query object.

<example>

```ruby
scope(
  :visible,
  lambda do
    if Current.permissions.include?('read:org:monitoring_lists')
      all
    elsif Current.permissions.include?('read:owned:monitoring_lists')
      owned_by(Current.membership)
    else
      none
    end
  end
)
```

</example>

<example type="invalid">

```ruby
def index
  @lists = if Current.membership.admin?
    MonitoringList.all
  else
    MonitoringList.owned_by(Current.membership)
  end
end
```

</example>

### Controllers must authorize a scope

`Authorization` is included in `Api::V2::BaseController` and calls `require_all_actions_to_authorize!`,
so an `after_action` raises `NoScopeCheckedError` for any action that never authorized. Use:

- `allowed?(Model.chain.of.permission_relevant.scopes)` — raises `PermissionError` when the scope
  resolves to a null relation, otherwise returns it.
- `authorize!(Model)` — picks `visible` for `index`/`show` and `editable` for `create`/`update`/
  `destroy`. Override per action with `authorize!(Model, write_scope: :owned)`.
- `skip_scope_check_for(:action)` — only for endpoints with genuinely no record boundary
  (`user_settings`, `announcements`, `errors`).

Chain non-permission scopes *after* the authorized scope, never before.

<example>

```ruby
def component_scope
  authorize!(Component).includable(serializer_params)
end
```

</example>

### Permissions come from `Current.permissions`

Check permission strings, never the role. `Membership#admin?` exists for display logic, not access
control.

`read:tlp_amber_strict` is **not** role-derived — `Membership#permissions` appends it based on the
organization flag:

```ruby
organization.can_see_tlp_amber_strict? ? base + ['read:tlp_amber_strict'] : base
```

So restriction visibility is an organization property surfaced as a permission. `can_see_tlp_amber_strict`
is `attr_readonly` on `Organization`.

### Restricted records read and write asymmetrically

`TlpAmberStrict`'s `default_scope` is `excluding_tlp_amber_strict.create_with(tlp_amber_strict: true)`.
Verified consequences:

| Call | Result |
|------|--------|
| `Component.count` | 78 — restricted rows excluded |
| `Component.including_tlp_amber_strict.count` | 79 |
| `Component.new.tlp_amber_strict` | **`true`** — new records are restricted by default |

Reads hide restricted rows; writes through the scope *create* restricted rows. When building a record
that must be broadly visible, set `tlp_amber_strict: false` explicitly.

### Escaping the restriction scope

`including_tlp_amber_strict` (implemented as `unscope(where:)`) is the sanctioned escape hatch — not
`.unscoped`, which would also drop tenant isolation. Legitimate in background jobs and sync paths that
must resolve a record regardless of restriction, then decide per organization:

<example>

```ruby
component = Component.including_tlp_amber_strict.find_by(id: event.component_id)
return unless component.restricted_for?(organization)
```

</example>

For associations, use the pre-declared restriction-aware reader rather than escaping at the call site:

<example>

```ruby
belongs_to(:component_including_tlp_amber_strict, -> { including_tlp_amber_strict })
```

</example>

Use `restricted_for?(organization)` for the per-organization decision and `became_restricted?` to
detect a record turning restricted (drives `Component::RestrictionCleanup::*` jobs).

<critical>

  - An action that authorizes nothing raises NoScopeCheckedError in dev/test but grants access in production — never silence it with skip_scope_check_for to make an error go away.
  - A `visible` / `editable` scope must fall through to `none`, never to `all`.
  - Never reach for `.unscoped` to see restricted records — use `including_tlp_amber_strict`.

</critical>
