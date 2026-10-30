---
paths:
  - "db/migrate/**"
  - "test/local/**"
---

# `test/local/` — Migration Tests and Local-Only Helper Tests

## What belongs in `test/local/`

`test/local/` is **reserved**. Exactly two kinds of file live there:

1. **Migration tests** — one per data migration, named `<migration_name>_test.rb`. Everything below
   this section is about these.
2. **Tests for local-only helpers** — dev tooling whose subject is itself untracked, so it cannot
   have a committed test: `migration_scope_guard_test.rb`
   (`config/initializers/migration_scope_guard.rb`), `fixture_console_helpers_test.rb`
   (`config/initializers/fixture_console_helpers.rb`).

Nothing else. A test whose subject is committed code belongs in the committed tree —
`test/models/`, `test/integration/`, `test/serializers/`, `test/lib/` — even when it is a security
audit, a leak probe, or a one-off you do not intend to keep. `test/local/` is untracked, so a test
parked there never runs in CI, no colleague ever sees it, and it rots silently as the branch moves
on underneath it.

A throwaway *measurement* — query counts, an N+1 probe, timing — is not a test at all. Write it as
a script in the scratchpad directory (see the `script-performance` skill) and delete it when the
question is answered.

<example type="invalid">

```text
test/local/inbox_n_plus_one_test.rb          # query-count probe → scratchpad script
test/local/tlp_leak_audit_test.rb            # audits committed code → test/integration/security/
test/local/inbox_item_serializer_test.rb     # committed subject → test/serializers/
```

</example>

<example>

```text
test/local/backfill_item_type_cache_test.rb  # migration test
test/local/migration_scope_guard_test.rb     # subject is an untracked local helper
```

</example>

## Context

Applies to any migration that reads or writes rows — backfills, `update_all`, `find_each`, raw `UPDATE`. Pure DDL (`add_column`, `add_index`, constraints) needs no test.

Migrations run with `Current.organization == nil` and `Current.membership == nil`, so **every `default_scope` in the app narrows the rows a migration touches, silently**. A backfill that reads correctly updates zero rows and raises nothing. `MigrationScopeGuard` (`config/initializers/migration_scope_guard.rb`) catches two shapes in the emitted SQL: `"<table>"."organization_id" IS NULL` for `OrgScoped`, and a `tlp_amber_strict = false` filter for `TlpAmberStrict`. Every other scope is invisible to it, and it only sees code paths that actually run. A test shows which rows the migration actually reached, alongside the manual before/after run the README requires.

## Requirements

### Write the test first and confirm it fails

The failure must be the real one: rows left untouched, not a missing constant.

### Put the test in `test/local/<migration_name>_test.rb`

- `test/local/` is listed in `.git/info/exclude` → untracked, never committed, never runs in CI
- Run it with `bin/rails test test/local/<file>` — a full `bin/rails test` picks it up too
- Never `git add` it

### Drive the migration through `exec_migration`

Migration files are not autoloaded — require by absolute path. `exec_migration` is the method `MigrationScopeGuard::CaptureSql` prepends; calling the migration's `up` directly bypasses the guard.

```ruby
require('test_helper')
require(Rails.root.join('db/migrate/20260702155544_backfill_item_type_cache.rb').to_s)

class BackfillItemTypeCacheTest < ActiveSupport::TestCase
  test('backfills item_type_cache for items in every organization') do
    Inbox::Item.unscoped.update_all(item_type_cache: nil)

    BackfillItemTypeCache.new.exec_migration(ActiveRecord::Base.lease_connection, :up)

    items = Inbox::Item.unscoped

    assert_operator(items.map(&:organization_id).uniq.size, :>, 1)
    assert_empty(items.where(item_type_cache: nil))
  end
end
```

For an irreversible migration, put the data loop in a migration subclass inside the test file and set up the pre-migration state by hand.

### Assert against the rows the default scopes hide

The test body also runs with `Current.organization == nil`, so read results back with `.unscoped`. Assert two things per backfill:

- **coverage** — nothing left unmigrated: `assert_empty(Inbox::Item.unscoped.where(item_type_cache: nil))`
- **reach** — the touched set spanned more than one organization, and included at least one row each relevant default scope would have excluded

| `default_scope` | Silently drops | Guard catches it |
|---|---|---|
| `OrgScoped` | every row, via `organization_id IS NULL` | yes |
| `ApiToken` | other orgs' tokens (caught), and all tokens when `Current.membership` is nil (missed) | partly |
| `Component`, `Notification` — `synced_at_least_once` | never-synced rows | no |
| `TlpAmberStrict` | `tlp_amber_strict: true` rows, and forces `true` on writes through the scope | yes, on reads — opt in with `including_tlp_amber_strict` |

### Respect `Current` in the migration body

- Prefer pure SQL (`execute`), which no default scope touches (Readme.md "Writing migrations"). The `::Current` bypass below works, but it's easy to get wrong (an association resolved outside it silently narrows the rows), which is why pure SQL is preferred. The rest of this section is for a migration that cannot avoid a model.
- Write `::Current`, never bare `Current` — inside a migration that constant resolves to `ActiveRecord::Migration::Current`
- Choose the bypass deliberately: `::Current.without_organization_and_membership_scopes` for a global sweep, `::Current.set(organization: org)` when the code inside needs one real org
- **Resolve records that feed `Current.set` inside the bypass, never as its argument** — an `OrgScoped` association evaluated outside returns `nil`, and the block then runs with no organization or membership at all

<example type="invalid">

`item.membership` loads while `Current.organization` is still nil, so it resolves to `nil` and the block sets `membership: nil`:

```ruby
Inbox::Item.unscoped.find_each do |item|
  ::Current.set(organization: item.organization, membership: item.membership) do
    item.update_column(:item_type_cache, item.item_type)
  end
end
```

</example>

<example>

One bypass around the whole sweep — associations resolve inside it:

```ruby
::Current.without_organization_and_membership_scopes do
  Inbox::Item.find_each { it.update_column(:item_type_cache, it.item_type) }
end
```

</example>

<critical>

  - NEVER put anything in `test/local/` that is not a migration test or a local-only helper test
  - NEVER commit a file under `test/local/`
  - NEVER assert on a model carrying a `default_scope` without `.unscoped` — the assertion passes against zero rows

</critical>
