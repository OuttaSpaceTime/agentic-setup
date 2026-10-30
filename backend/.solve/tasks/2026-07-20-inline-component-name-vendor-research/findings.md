# Inline ComponentVendor & ComponentName — Findings

## 1. Current model (confirmed)

Two shared lookup tables, `include Nameable`, **no `organization_id`**, not `Syncable`:
- `component_names` — `name`, `abbreviation`, `active` (`app/models/component/name.rb`)
- `component_vendors` — `name`, `abbreviation`, `url`, `sec_url`, `active` (`app/models/component/vendor.rb`)

Consumers:
- `Component` — FK `component_name_id` / `component_vendor_id`, both optional (`component.rb:192-193`)
- `Notification::Advisory` — FK `component_vendor_id` NOT NULL (`advisory.rb:5`)

They are **global** because the whole component/notification catalog is global: `components`,
`notifications`, `notification_advisories` also lack `organization_id`; `Component` and
`Notification` use `default_scope { synced_at_least_once }` (a sync-status filter, not a tenant
filter). Auth is by permission (`read:components` / `read:notifications`, all-or-none), not ownership.

## 2. Domain model, one example

A **Component** is a `<vendor> <name> <version>` triple — the exact thing monitored, e.g.
Component `one` = vendor `adobe` ("Adobe") + name `vnc` ("VNC") + version `1.1` → "Adobe VNC 1.1".
`Component::Name` / `Component::Vendor` are just **dedup lookup tables** for the string parts;
nothing is authorized or fetched *as* a name/vendor.

An **Advisory** (`Notification::Advisory`) is a vendor's own published bulletin referenced by a
Notification, tagged with its publisher, e.g. advisory "Release 6.15.1" on notification
`with_vulnerabilities`, vendor `pnpm`.

The vendor row is shared because one company plays two roles: maker of a component *and* publisher
of an advisory. But nothing reads that shared identity — the advisory serializer renders only
name+url, and `has_many :component_vendors, through: :advisories` has zero call sites. Inlining
turns the shared row into two independent strings, losing only a link no use case uses.
