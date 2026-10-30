---
name: Membership references — never snapshot
description: Persistence rule — events, items, and any notification record must reference memberships via FK only, never snapshot name/email; render "(deleted)" when the FK resolves to nil
type: feedback
originSessionId: 27c19d18-f294-4c83-9e08-b74c67d86543
---
Never store snapshots of membership data (name, email, role-as-string, etc.) on events, inbox items, notifications, or any persistence layer. Always `belongs_to :membership` (or similar FK, typically with `optional: true` and `on_delete: :nullify`). At render time (item `title`/`body`, mailer view), resolve through the FK; if the membership no longer exists, render "(deleted)" or an equivalent marker.

**Why:** (inferred — confirm with Felix if it matters for edge cases) Single source of truth for membership data; avoids stale/orphaned PII in notification records; aligns with existing `BasicDataUpdatedEvent` which stores `actor_id` only, no `actor_name`/`actor_email` columns.

**How to apply:**
- Designing a new event/item/notification table: FK to `memberships`, never `<role>_name` / `<role>_email` columns.
- Rendering: `event.actor&.name || '(deleted)'` pattern, or whatever fallback the view layer expects.
- Mailer migrations: when replacing `initiator_name` / `initiator_email` mailer params, resolve them from the actor FK at job run time; accept that a deleted actor results in "(deleted)" in the email body.
- This rule applies to ALL membership references (actor, target, recipient, etc.), not just the initiator.
