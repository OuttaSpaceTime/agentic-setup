## Intro

The following discussion from !623 should be addressed:

- [ ] @niklas.haeusele.ext started a [discussion](https://code.siemens.com/vilocify/vilocify-frontend/-/merge_requests/623#note_58090729):  (+2 comments)

    > We need a followup ticket here, does not have to happen in this PR: Adopt this PR to reuse the ListResourceStateService instead. i want to know whether we can type safe use that service with the inbox union type without having to add an extra updater service.

**Timebox: 1 day.** Research spike — the deliverable is a documented decision + recommendation, not production code.

## Acceptance criteria

- [ ] Documented answer: can `InboxItemDetailService` reuse `ListResourceStateService` with the inbox entry union (`IInboxNotificationEntry | IInboxMembershipExpiryEntry`) type-safely?
- [ ] Explicit conclusion on whether `MembershipExpiryActionsService` can be removed.
- [ ] A recommended approach chosen (see Notes) with a rough effort estimate.
- [ ] Follow-up implementation issue created if reuse is recommended; otherwise the reasoning is recorded on this issue.
- [ ] Any spike code stays on a throwaway branch — nothing is merged from this issue.
