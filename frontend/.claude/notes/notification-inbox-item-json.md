# Monitoring List Security Notifications Inbox Item Page renders the body from JSON

## Intro

`InboxItemDetailComponent` renders `data.attributes.description` as one preformatted blob for every type. The backend now serializes `ml_notification` items as structured JSON: top-level `monitoringListName` + `monitoringListId`, plus a paginated `inboxNotificationEntries` relationship returned as `included` resources (pagination links under the relationship's `links`). Build a structured UI for this card; other types keep rendering plaintext `description`.

## Acceptance criteria

- [ ] Heading shows the monitoring list name and id; `monitoringListId: null` => **"(deleted)"**.
- [ ] Lists notifications: title, priority (reuse `PriorityTileComponent` / `priority-maps`), published date, updated date.
- [ ] `remediation` shown only when present (attribute omitted when no solution status).
- [ ] `changes` shown only when present (attribute omitted when no history summary).
- [ ] Entry with `deleted: true` => placeholder, no title/priority/dates.
- [ ] `data: []` => empty state, not an empty list.
- [ ] Entries spanning >1 page can be loaded further (relationship `next` link).
- [ ] Non-`ml_notification` types render unchanged (plaintext `description`).

### Test cases

- [ ] ML present vs deleted ("(deleted)" heading).
- [ ] Entry with / without `remediation`.
- [ ] Entry with / without `changes`.
- [ ] Deleted entry placeholder mixed with live entries.
- [ ] Empty list => empty state.
- [ ] Multi-page: second page appends.

## Notes

```ts
type InboxItem = {
  shortDescription: string
  itemType: 'ml_notification'
  monitoringListName: string
  monitoringListId: number | null    // null => "(deleted)"
  read: boolean; createdAt: string; updatedAt: string
  // rel inboxNotificationEntries -> InboxNotificationEntry[] (data: [] when none)
}
type InboxNotificationEntry =
  | { notificationId: number; title: string
      priority: 'critical' | 'major' | 'minor' | 'informational' | 'withdrawn'
      remediation?: string           // omitted when no solution status
      publishedAt: string; updatedAt: string
      changes?: string               // omitted when no history summary
      deleted: false }
  | { deleted: true }
```

- Page: `src/app/features/inbox/pages/inbox-item-detail/inbox-item-detail.component.{ts,html}`.
- `JsonApiResponse` (`src/app/shared/jsonapi/client.ts`) does not model `included` / `data.relationships` — add both (shared with the admin-expiry issue; first to land does the plumbing).
- `IInboxItem` (`src/app/shared/jsonapi/resources.ts`): add the new optional attrs, stop assuming `description` always present, add `IInboxNotificationEntry`.
- Reuse: priority rendering from `@features/notifications` (`priority-maps.ts` / `PriorityTileComponent`), `CardIconTextComponent`, `DatePipe`.
- Backend: branch `1083-introduce-a-proper-schema-for-the-notification-inbox-item` (`Inbox::ItemSerializer`, `Inbox::NotificationEntrySerializer`).
