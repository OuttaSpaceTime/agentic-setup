---
paths:
  - "app/**/*.rb"
---

# Multi-Tenant Scoping

## Context
- Multi-tenant app using `Current` (ActiveSupport::CurrentAttributes) — NOT acts_as_tenant
- Models include `OrgScoped` concern applying `default_scope` by `Current.organization`
- `.unscoped` bypasses ALL scopes including critical tenant isolation

## Requirements

> `OrgScoped` is not the only `default_scope`. `Component` and `Notification` also include
> `TlpAmberStrict`, whose escape hatch is `including_tlp_amber_strict` — never `.unscoped`.
> See `.claude/rules/020-authorization.md`.

- ❌ NEVER use `.unscoped` in controllers, serializers, or general business logic
- ✅ Use `Current.without_organization_and_membership_scopes { }` to explicitly bypass tenant scoping
- ✅ Rely on default scopes — they automatically filter by current organization

### Valid `.unscoped` Exceptions

Only in these specific cases:
1. **Syncable concern** — `find_or_create_placeholder` finding records by external ID across orgs
2. **Sync jobs** — working with non-org-scoped shared tables (e.g. `Component::Vendor`, `Component::Name`)
3. **Cleanup jobs** — cross-organization maintenance operations
4. **IndexSyncer** — checking sync status across all organizations
5. **Test support** — `scope_assertions.rb` validating scope behavior

<example>

```ruby
# Rely on default scope in controllers
def index
  components = Component.all  # automatically scoped to Current.organization
  render_json(components)
end
```

</example>

<example>

```ruby
# Explicit bypass using Current API
membership = Current.without_organization_and_membership_scopes do
  Membership.find_by(user: user, organization: org)
end
```

</example>

<example>

```ruby
# Sync job — shared table
vendor = Component::Vendor.unscoped.find_or_initialize_by(id: attrs['id'])
```

</example>

<example type="invalid">

```ruby
# Controller using .unscoped
components = Component.unscoped.where(organization: Current.organization)
```

</example>

<example type="invalid">

```ruby
# Model method using .unscoped instead of Current API
def self.find_by_external_id(id)
  unscoped.find_by(external_id: id)
end
```

</example>

<critical>

  Using .unscoped in application code exposes data across tenant boundaries — a severe security vulnerability.
  Before using .unscoped, ask: "Does this need to work across ALL organizations?" If yes, use Current.without_organization_and_membership_scopes. If no, rely on default scopes.

</critical>
