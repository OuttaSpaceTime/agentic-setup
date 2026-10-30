---
name: reference-jsonapi-serializer-relationships
description: jsonapi-serializer gotchas for paginated/conditional relationships in this repo
metadata: 
  node_type: memory
  type: reference
  originSessionId: 12a10b21-098b-42a5-b21a-c1f4fc9e7f7c
---

vilocify-portal serializers use `jsonapi-serializer` 2.2.0 (`ApplicationSerializer`).

**Empty `relationships: {}` gotcha:** once ANY `has_many`/`belongs_to` is declared on a serializer, every serialized record emits a `relationships` key — even when the relationship's `if:` proc excludes it, the gem still renders `relationships: {}` (see `relationships_hash` in serialization_core.rb). So adding a conditional relationship to a SHARED serializer (e.g. `Inbox::ItemSerializer`, used by both index summary and single-item show) forces the collection/summary OpenAPI schema to also allow an (always-empty) `relationships` object, or `assert_api_conform` fails.

**Per-relationship pagination links:** `has_many(..., links: { first: ->(rec, params){...}, ... })` accepts a hash of `(record, params)` procs with ARBITRARY keys (first/prev/next/last), so you can inject cursor links through serializer params. Feed the page + links in via the controller's `render_jsonapi(item, include: [...], params: {...})`. Gate the relationship on the param being non-nil so other actions (e.g. update) don't render an empty relationship with null pagination links.

**In-memory cursor pagination:** the AR `Paginator`/`JsonApiCursor` only paginate relations. For an in-memory list (e.g. `Membership::AdminExpirySummaryItem#membership_ids`, which keeps tombstone ids), `Inbox::AdminExpiryEntries` keyset-paginates the sorted array and reuses `Paginator::JsonApiCursor.encode_cursor/decode_cursor` + `build_pagination_links(links, path)` so cursors/links match the rest of the API.

**Canonical unified inbox-entry pattern (1083 ml_notification + 1084 admin_expiry agree):** per structured item type — (1) `Inbox::Item#<type>?` predicate (`itemable_type == '...'`); (2) `Itemable#<type>_entries(page: {})` returns a `Paginator::PaginatedArray`; (3) `Inbox::ItemSerializer` declares `has_many(:inbox_<type>_entries, serializer:, if: param-present, links: {4 (rec,params) procs digging params[:<type>_entries_links]}) { params[:<type>_entries] }` and gates `description` off for that type; (4) controller `<type>_options(item)` returns `{}` or `{include: [:inbox_<type>_entries], params: {<type>_entries:, <type>_entries_links: build_pagination_links(entries.links, api_v2_inbox_item_path(item))}}`, called via `render_jsonapi(item, **opts)`. Entry serializer = oneOf live/tombstone (conditional attrs gated on presence + always-rendered `deleted`). NO `sort` query param on the relationship — matches preexisting relationship endpoints (vulnerabilities/components expose only `page[size/after/before]`, default `id` cursor). Variances are data-driven only: AR relation → `json_api_sort_and_paginate`, in-memory list → `Inbox::AdminExpiryEntries`; scope-bypass (`without_organization_and_membership_scopes { item.itemable }`) ONLY when the itemable's org is nullable (admin_expiry `optional: true`), NOT for non-null-org itemables (notification). Both add an empty `relationships: {}` block to `vilocifyInboxItemSummary.yml` (the has_many gotcha above).

Related: [[feedback_membership_references]], [[feedback_no_jsonb_snapshots]], [[feedback_delegated_type_sti]].
