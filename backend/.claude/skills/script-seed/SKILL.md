---
name: script-seed
description: >-
  Write a quick, idempotent one-off Ruby script that creates ActiveRecord records in the
  vilocify-portal development database so a feature can be browsed or QA'd manually — e.g. "give
  superuser_as_admin_in_a an inbox item with 50 revisions", "create a monitoring list with 200
  subscribers", "seed a component with an EOL notification". Also covers reproducing edge cases
  (nil/omitted attributes, deleted associations, boundary enum values) pulled from the OpenAPI
  schema or tests. Use this whenever the user asks for a throwaway/one-off/quick script to add,
  seed, load, or create test data/records for manual testing or browsing in the dev DB — not for
  large synthetic datasets (that's lib/database_seeder.rb), not for test fixtures (that's
  test/fixtures/*.yml), and not for measuring query cost / benchmarking an N+1 against seeded data
  (that's the script-performance skill).
---

# Script: Seed

A recipe for writing small, safe, rerunnable scripts that populate the vilocify-portal
**development** database with real records for manual testing — as opposed to
`lib/database_seeder.rb` (bulk-generates a large realistic dataset) or `test/fixtures/*.yml`
(used by the test suite). This is for "I need to look at this one thing in the browser."

## Why this needs its own recipe

A naive `Model.create!` script in this codebase runs into several non-obvious walls: multi-tenant
scoping hides records unless `Current` is set correctly, a membership can't be saved without
billing headroom, and the names people say out loud ("org_a", "superuser_as_admin_in_a") are
fixture *labels*, not the actual column values. Guessing at any of these produces a script that
either raises deep in a validator, or — worse — silently succeeds by creating a parallel duplicate
that the user's browser session never sees. The steps below exist to catch that class of mistake
before it costs a debugging round trip.

## Procedure

### 0. Reuse before you write

These scripts get recreated over and over, so start by looking for one that already exists rather
than writing a fresh one. Check `.solve/scripts/` (`ls .solve/scripts/`) for a script whose name or
body already does this, or does something close enough to adapt. Three outcomes, in order of
preference:

- **Rerun as-is.** They're written idempotent (Step 4), so if a matching script is already there,
  just run it again — no new file needed.
- **Copy and tweak.** If a near-match exists, copy it to a new name and change the few lines that
  differ, instead of rebuilding the association graph from scratch.
- **No script at all.** If the ask is a one-liner (flip one attribute, print one count), it may not
  warrant a file — do it inline with `bin/rails runner` and skip the rest of this procedure.

Only write a brand-new script when none of the above fits.

### 1. Pin down the target and scope

Get precise about: which model chain, roughly how many records, and whether the ask implies edge
cases ("different attributes can be nil or deleted", "cover every state"). If edge cases are in
scope, don't invent them — pull the actual valid/nil/omitted states from the OpenAPI schema
(`openapi/components/schemas/*.yml`) and the model's serializer/tests, the same way you'd source
any other fact per this repo's investigation-before-action rule. Treat "I want many entries" as
"more than one page" — check the model's `default_page_size` and aim comfortably past it.

### 2. Resolve fixture-speak to real values

If the user names something using fixture vocabulary (a YAML key like `org_a`,
`superuser_as_admin_in_a`, `active`), that label is **not** the value stored in the database — it's
only the fixture file's key. Open the actual fixture file and read the real attribute:

```
$ grep -n -A2 "^org_a:" test/fixtures/organizations.yml
org_a:
  name: Organization A
```

The organization's real `name` is `"Organization A"`, not `"org_a"`. Build your `find_or_create_by!`
lookups on that real value. Skipping this step is the single most likely way to end up creating a
decoy record that looks right in your script's output but is invisible to the user's actual login
session — you won't find out until they report a 404.

If test fixtures happen to already be loaded into the dev DB (fixtures use deterministic
IDs/UUIDs derived from the label), your script's `find_or_create_by!` will naturally find and reuse
them as long as you looked up the real attribute value. Prefer extending an existing record over
creating a parallel one — e.g. look for an existing inbox item on the target membership before
building a whole new event/item chain from scratch.

Reuse at the right layer, not the shallowest one: a resource that's shared per-org (a
`Inbox::Event::MonitoringList::Notification`, an `Inbox::Event::MonitoringList::ComponentsUpdated`) should be found
and reused, but the `Inbox::Item`/itemable is per-membership and usually needs its own fresh row
even when the event is shared. Check an existing item's associations in the dev DB (e.g. does this
event already fan out to other memberships?) before deciding what to share versus create.

### 3. Know the standing gotchas in this app

These have each caused a real failure while writing seed scripts here — check whether they apply
before you hit them at runtime:

- **Multi-tenant scoping**: most models are `OrgScoped` via `Current`. Outside a request, wrap
  cross-org lookups in `Current.without_organization_and_membership_scopes { ... }`, and wrap
  anything that reads org-scoped associations back out in `Current.set(organization: org) { ... }`.
  Never reach for `.unscoped` in the script's *logic* — it's fine for the lookup shims above, but
  see `.claude/rules/010-multi-tenant-scoping.md`.
- **Membership billing limit**: `Membership::LimitValidator` rejects a new membership unless
  `organization.membership_limit` (sum of `current_orders.membership_request_credit` for the org's
  *current* consumption period) exceeds the active membership count. If the org has no current
  consumption period / order yet, create one first:
  ```ruby
  period = organization.current_consumption_period ||
    organization.consumption_periods.create!(period: Date.current..1.year.from_now.to_date)
  period.orders.create!(name: 'Individual', membership_request_credit: 5) if period.membership_order_count < 5
  ```
- **Membership invitation_state**: defaults to `"pending"`, which `Api::V2::SessionsController`
  filters out when listing which orgs a user can log into. Set `invitation_state: 'accepted'`
  explicitly or your seeded membership will be unselectable in the dev login form.
- **One user, one org, several memberships**: `role` is part of the uniqueness key
  (`user_id`+`organization_id`+`role`), and fixture users routinely hold more than one role in the
  same org (e.g. `superuser` has separate `user`/`user_manager`/`security_officer`/`admin`
  memberships in "Organization A"). `Membership.find_or_create_by!(user:, organization:)` *without*
  `role:` is ambiguous — it'll silently match whichever one Postgres happens to return first, which
  is not necessarily the one implied by a fixture label like `superuser_as_admin_in_a`. Always
  include `role:` in the lookup when the label specifies one.
- **Notification visibility**: `Notification` has `default_scope { synced_at_least_once }`, which
  requires `last_successful_sync_at` to be present — an otherwise-valid notification without it is
  invisible everywhere.
- **`organization_id` doesn't live in the same place for every itemable**: some events carry it
  (`Inbox::Event::MonitoringList::Notification#organization`), some don't (`Inbox::Event::Component::SupportDropped`
  has no `organization` column at all — only the `Item` does). Don't assume the shape of one
  itemable's chain generalizes to the next one; check the actual columns/associations on the
  specific event and item classes you're building.

When a model outside this list rejects your input, don't guess a fix — read its `validates`/
`belongs_to`/concern list and any custom validator it pulls in, the same way these were found.

### 4. Write it idempotent

Use `find_or_create_by!` on whatever the record's natural/business key is (name, email,
event+membership+org, etc.), not `create!`. For "many records" loops, compute the remaining count
to add rather than a fixed count, and short-circuit entirely if a target is already met:

```ruby
existing = notification_item.notification_revisions.count
if existing >= TARGET_REVISION_COUNT
  puts("already has #{existing} revisions, nothing to add")
else
  # ... add (TARGET_REVISION_COUNT - existing) more
end
```

This makes the script safe to hand to the user to rerun themselves, and safe for you to rerun while
iterating without piling up duplicates.

Not every itemable has a natural key to `find_or_create_by!` on. Some (like
`Inbox::Item::Membership::ExpirySummary`) aggregate many memberships through child entry rows
instead of belonging to a single record — there's no key that identifies "the" row you want.
For those, idempotency means finding the existing owning `Inbox::Item` first and adding the missing
child rows (`find_or_create_by!` on the entry) rather than trying to create-or-skip the parent.

### 5. Dry-run before it's real

Wrap the whole body in a transaction and gate the rollback behind an env var, so you can sanity
check the counts/logic before anything persists:

```ruby
ActiveRecord::Base.transaction do
  # ... build everything ...
  puts("done")
  raise(ActiveRecord::Rollback) if ENV['DRY_RUN']
end
```

Run `DRY_RUN=1 bin/rails runner .solve/scripts/<name>.rb` first, read the output, then rerun without
`DRY_RUN` once it looks right.

Two easy ways to lose the rollback: if the script has an early exit (an `if already-exists?
puts(...); next end` inside the transaction), the `raise(ActiveRecord::Rollback) if ENV['DRY_RUN']`
still has to be reachable on that path too — put it before the `next`, not only at the end of the
happy path. And if you need a relative timestamp (`3.days.from_now` for an expiry), assign it to a
local variable, not a top-level constant — RuboCop's `Rails/RelativeDateConstant` cop will rewrite a
constant assignment into something broken.

### 6. Place it in `.solve/scripts/`

These are throwaway, developer-local scripts — they do **not** belong in the checked-in `script/`
directory. Write them to `.solve/scripts/<name>.rb`, which is already git-excluded (`.solve/` is in
`.git/info/exclude`), so they never show up in a diff or get committed. In a worktree `.solve/scripts`
is a symlink to the main checkout's copy (set up by the create-worktree skill), so a script written
here is shared across every worktree; create the directory only if missing (`mkdir -p .solve/scripts`).

Run them with `bin/rails runner .solve/scripts/<name>.rb` — no shebang or `require_relative` needed,
since `bin/rails runner` loads the environment for you. Don't build it as an inline
`bin/rails runner '...'` one-liner if it's going to be reused — give it a real file so it can be
rerun later.

### 7. Verify by querying it back, not by trusting the create calls

`create!` not raising means the row saved — it doesn't mean the association graph looks the way you
intended, or that the serializer will render what you expect. After running for real, query the
record back out (inside the right `Current.set(organization: ...)` context) and print the fields
that matter:

```ruby
Current.set(organization: org) do
  item = Inbox::Item.find(id)
  puts(item.itemable.notification_revisions.includes(:notification).count)
end
```

A `puts` on the queried-back data surfaces mistakes like the membership limit error or a
wrong-organization decoy immediately, instead of leaving them for the user to discover in the
browser.

### 8. Run the project's quality tools

Per `.claude/rules/800-quality-tools.md`: `bin/rubocop -A .solve/scripts/<name>.rb` and
`bin/editorconfig-checker .solve/scripts/<name>.rb`. Report the outcome of both. Both tools resolve
their config by walking up from the target file's directory — run them from the repo root against
the `.solve/scripts/`-relative path (as above), not against an absolute path outside the repo, or
they'll silently fall back to generic defaults and report offenses (or a false-clean pass) that
don't reflect this project's actual `.rubocop.yml`/`.editorconfig`. Passing the explicit file path
is what makes this work even though `.solve/` is a hidden directory.

> For *measuring* against a seeded dataset — query counts, an N+1 fix, worst-case latency, all
> non-destructively — see the **script-performance** skill instead.

## If it turns out wrong after the fact

If the user reports the data isn't where they expected (wrong org, 404, missing from a list), don't
re-guess — go find the exact line that failed (a stack trace frame, a controller's `find` /
`where` call) and read what scope it's actually applying, the same way you'd debug any other bug in
this codebase. If the diagnosis shows the script created something extraneous (a decoy org, orphan
records), clean those up explicitly — `organization.destroy` cascades most of the tree via the
model's `dependent: :destroy`/FK `on_delete: :cascade` chains, but check for anything that isn't
org-scoped (e.g. `Notification` rows are global, not tied to an org, and won't get swept up) and
destroy those separately. Then fix the script itself so a future run lands in the right place.

## Reference example

Example: an `Inbox::Item::MonitoringList::Notification` inbox item for
`superuser_as_admin_in_a` with revisions covering every priority, every remediation level, a
missing-remediation case, a missing-changes case, a deleted-notification case, and enough filler to
span several pages. Browse the git-excluded `.solve/scripts/` for a concrete starting point to copy
from (Step 0).
