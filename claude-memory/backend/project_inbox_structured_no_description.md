---
name: project-inbox-structured-no-description
description: "Structured inbox item types (notification, admin-expiry) intentionally never render a description attribute"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4c9ba140-ca20-451d-a832-1b4f95e833db
---

For the structured-schema inbox item types — `MonitoringList::NotificationItem` (notification) and `Membership::AdminExpirySummaryItem` (admin-expiry) — the JSON:API representation deliberately omits the free-text `description` attribute. These types present structured fields (`monitoringListName`/`monitoringListId`, `organizationName`, `retentionDays`) plus paginated entry relationships instead. Only the plain/legacy item types (rendered by `Inbox::ItemDetailSerializer`) expose `description`.

**Why:** Felix's deliberate design for the new structured inbox JSON approach — structured attributes + paginated entries replace the prose description. An OO critic flagged the missing `description` as a "silently dropped contract"; it is intentional, not a bug.

**How to apply:** Never add `description` to `Inbox::NotificationItemDetailSerializer` or `Inbox::AdminExpiryItemDetailSerializer`. The per-type serializers enforce this structurally (they don't declare the attribute, so it cannot be emitted) — keep it that way; don't reintroduce a uniform "detail always has description" contract. See [[feedback_inbox_entries_pattern]].
