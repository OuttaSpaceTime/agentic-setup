# Admin Summary Inbox Item Page renders the body from JSON

## Intro

`InboxItemDetailComponent` renders `data.attributes.description` as one preformatted blob for every type. The backend now serializes `admin_expiry_summary` items as structured JSON: top-level `organizationName` + `retentionDays`, plus a paginated `inboxAdminExpiryEntries` relationship returned as `included` resources (pagination links under the relationship's `links`). Build a structured UI for this card; other types keep rendering plaintext `description`.

## Acceptance criteria

- [ ] Heading shows the organization name (`organizationName`); `null` => **"(deleted)"**. Keep the "prolong via User Management" explainer.
- [ ] Lists affected memberships: email, human role (`MembershipRolePipe`), status.
- [ ] Status rendered per case: **no expiration**, **expired on `<date>`**, **expiring on `<date>`** (`expiresAt` via `DatePipe`; `expiresAt` is null only for `no_expiration`).
- [ ] Entry with `deleted: true` => placeholder (e.g. "[membership deleted]"), no email/role/status.
- [ ] Retention note uses `retentionDays` from the response, not a hardcoded number.
- [ ] `data: []` => empty state, not an empty list.
- [ ] Entries spanning >1 page can be loaded further (relationship `next` link).
- [ ] Non-`admin_expiry_summary` types render unchanged (plaintext `description`).

### Test cases

- [ ] Org present vs deleted ("(deleted)" heading).
- [ ] Status `no_expiration` / `expired` / `expiring`.
- [ ] Deleted entry placeholder mixed with live entries.
- [ ] Empty list => empty state.
- [ ] Multi-page: second page appends.

## Notes

```ts
type InboxItem = {
  shortDescription: string
  itemType: 'admin_expiry_summary'
  organizationName: string | null   // null => "(deleted)"
  retentionDays: number              // currently 30
  read: boolean; createdAt: string; updatedAt: string
  // rel inboxAdminExpiryEntries -> InboxAdminExpiryEntry[] (data: [] when none)
}
type InboxAdminExpiryEntry =
  | { membershipId: string; email: string
      role: 'admin' | 'user' | 'user_manager' | 'security_officer'
      status: 'no_expiration' | 'expired' | 'expiring'
      expiresAt: string | null       // null when 'no_expiration'
      deleted: false }
  | { deleted: true }
```

- Page: `src/app/features/inbox/pages/inbox-item-detail/inbox-item-detail.component.{ts,html}`.
- `JsonApiResponse` (`src/app/shared/jsonapi/client.ts`) does not model `included` / `data.relationships` — add both (shared with the notification issue; first to land does the plumbing).
- `IInboxItem` (`src/app/shared/jsonapi/resources.ts`): add the new optional attrs, stop assuming `description` always present, add `IInboxAdminExpiryEntry`.
- Reuse: `MembershipRolePipe` (`@shared/pipes/membership-role.pipe`), `CardIconTextComponent`, `DatePipe`, `ui-card`/`ix-typography`.
- Backend: branch `1084-introduce-a-proper-schema-for-the-admin-expiry-inbox-item` (`Inbox::ItemSerializer`, `Inbox::AdminExpiryEntrySerializer`; OpenAPI `vilocifyInboxAdminExpiryEntry.yml`, `vilocifyInboxItem.yml`).
