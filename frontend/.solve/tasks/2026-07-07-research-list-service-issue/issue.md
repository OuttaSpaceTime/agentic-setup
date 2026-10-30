## Intro

In https://code.siemens.com/vilocify/vilocify-frontend/-/work_items/607 we had to use
`untracked` to break an infinite loop in the list service filter. `nextPageCursor` is read
**and** written inside the filter method, so writing it re-triggers the effect that reads
it — an endless loop that fired ~150 requests when opening `/inbox` with more than 20 items
and hit the backend rate limit (429). See the fix in
https://code.siemens.com/vilocify/vilocify-frontend/-/merge_requests/629.

`untracked` patches the symptom, but we are not confident it is the right long-term design —
it is a first use of `untracked` in this codebase. This issue is to research a cleaner approach.

## Acceptance criteria

- [ ] The root cause (reading + writing `nextPageCursor` in the same reactive context) is
      documented, with the exact signals/effects involved.
- [ ] At least two alternative designs are evaluated (e.g. splitting next-cursor fetching from
      setting, as done in the inbox list detail show; or restructuring the service's signal graph
      so the cursor is not both an input and output of the same effect).
- [ ] A recommendation is made on whether to keep `untracked` or replace it, with reasoning.
- [ ] Infinite scroll is confirmed correct (loads past the first 20 items) under the chosen
      approach, and opening `/inbox` sends only the expected number of requests.

## Notes

- Fix that introduced `untracked`: https://code.siemens.com/vilocify/vilocify-frontend/-/merge_requests/629
- Original bug report: work item 607 — "Inbox loading sends a lot of requests" (429 on `/inbox`).
- The inbox list detail show already splits next-cursor fetching from setting; that pattern may
  be a viable model for the service.
- `untracked` is intended exactly for reading a signal you don't want as a trigger dependency —
  so this may already be correct; the research should confirm or refute that.
