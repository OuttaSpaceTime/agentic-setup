---
name: feedback_inbox_entries_pattern
description: "Inbox itemable paginated \"entries\" relationships must mirror the notification pattern — AR-backed pagination + serialize the record directly"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c629c14d-52ba-4e11-be06-d9e54f5ee20e
---

When a new `Inbox::Itemable` exposes a paginated "entries" relationship (e.g. `expiry_entries`, `notification_entries`), mirror the canonical notification pattern exactly — do NOT invent a bespoke PORO + in-memory keyset paginator.

**Why:** Felix rejected the first Admin Expiry implementation (branch 1084) precisely because it used a "completely different approach for serialization and pagination" than the sibling notification branch (1083). Alignment with the established pattern matters more than clever handling of edge cases.

**How to apply:**
- **Pagination:** `SomeModel.where(id: ...).includes(:assoc).json_api_sort_and_paginate(page: page)` returning the standard paginated relation with `.links`. The model must include `JsonApiPagination` + `Orderable` + `Readable`. The real `Paginator` emits links in the exact `{ page: { after/before: cursor, size: }, sort: }` shape that the `assert_entry_page_links` test helper builds via `build_pagination_links` + `cursor` + `assert_links_equal`.
- **Serialization:** serialize the AR record directly with attribute blocks + `if:` guards (like `Inbox::NotificationEntrySerializer`), not a wrapper PORO.
- **Tombstones:** AR pagination can't show rows that don't exist. Notification keeps tombstones because `NotificationRevision` rows persist when the notification is deleted; Admin Expiry stores `membership_ids` (uuid[] array) so a deleted membership has no row. Felix chose to **drop tombstones** (deleted memberships silently omitted) to keep the AR mirror, rather than retain the bespoke paginator. Prefer the aligned mechanism over edge-case fidelity unless asked otherwise.
- The controller's per-type options method still loads the itemable inside `Current.without_organization_and_membership_scopes { item.itemable }` (memoizes it for the serializer) when the itemable carries an org that may be nullified.

Related: [[feedback_no_jsonb_snapshots]], [[feedback_membership_references]], [[reference_jsonapi_serializer_relationships]].
