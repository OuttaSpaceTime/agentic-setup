---
name: project_inbox_paginated_detail_entries
description: Inbox detail serializer pagination — pagination moved to the controller (Pagy keyset); serializer just reads params
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a294372-8b82-4bee-a7f3-1c7cafc39b1d
---

Inbox item *detail* views embed a paginated has_many of related records (e.g. `MonitoringList::NotificationItem` → `inboxNotificationEntries` paginating `notification_revisions`; `Membership::AdminExpirySummaryItem` → `inboxAdminExpiryEntries` paginating `admin_expiry_entries`).

**Current approach (1083 "Apply review feedback" + 1084 rebased onto it, 2026-06-30): pagination lives in the CONTROLLER, not the serializer.** The old serializer-side machinery was deleted: `ApplicationSerializer#paginated_has_many`, the `paginated_sources` registry, the `#initialize` override, `ActionJsonApi::PaginationLinkBuilder`, and `pagination_base_path`. `ApplicationSerializer` is now just `path_helpers` + an `inherited` hook resetting `relationships_to_serialize`.

**How it works now:**
- `Api::V2::Inbox::ItemsController` includes `Pagy::Method`. `show` builds params per relation and merges: `params: notification_entries_params(item).merge(admin_expiry_entries_params(item))`.
- Each `*_entries_params(item)` method: early-returns `{}` unless the include is requested AND the itemable responds to the relation; else orders the relation (`.order(:id)`) and runs `pagy(:keyset, rel, jsonapi: true, page_key: 'after', limit_key: 'size', limit: rel.default_page_size, max_limit: 100)`, returning `{ inboxFooEntries: { records: entries, pagy: pagy } }`.
- The detail serializer uses a plain `has_many(:inboxFooEntries, serializer:, if: proc { |_i, p| p.key?(:inboxFooEntries) }, links: { first: ->(_i,p){ p[:inboxFooEntries][:pagy].page_url(:first) }, next: ->(_i,p){ ...page_url(:next) } }) { |_i, p| p[:inboxFooEntries][:records] }`. Cursor links are **first/next only** (openapi `cursorPaginationLinks.yml`), no prev/last.
- Entry join models include `JsonApiResource` and define `readable_columns`/`orderable_columns`/`default_page_size` (mirror `MonitoringList::NotificationRevision`).
- `update` still renders with `params: { page: page_params }` → entries omitted (the `if:` key gate isn't satisfied).

**2nd-source decision (admin expiry, the source #2 anticipated below):** we did NOT lift wiring into a base registry. Felix chose **JRY parallel methods** in the controller — one explicit `*_entries_params` per itemable type, merged in `show`. Repeat the Pagy boilerplate per method; no abstraction. (Supersedes the old "lift to `Inbox::ItemSerializer` base registry" plan, which assumed the deleted serializer-side approach.)

Related: [[feedback_inbox_entries_pattern]], [[reference_jsonapi_serializer_relationships]], [[project_inbox_structured_no_description]].
