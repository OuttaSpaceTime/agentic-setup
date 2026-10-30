---
name: feedback_unnecessary_safety_returns
description: "Don't add nil-guard early returns unless deletion can actually produce the nil; AI over-guards"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c9f0e014-d9fa-4538-ad43-fcb115941f47
---

AI (me) tends to add too many defensive `return if x.nil?` / `next unless x` early returns that can never fire. Before keeping or adding a nil guard, prove the nil is reachable; if it isn't, remove it.

**Why:** Niklas repeatedly flagged guards as "AI returns" — e.g. `next unless organization` where `organization` was looked up from rows just plucked in the same query (so it's always present), and `return if event.component_id.nil?` on an event whose `component_id` is always set at creation and never nullified.

**How to apply:** Distinguish legit from dead guards by checking what can produce the nil:
- **Legit** — referenced record can be deleted/nullified. `Component::SupportDroppedEvent` has an `on_delete: :nullify` FK to components, so `event.component_id` really goes nil → `return unless event.component_id` is correct. ActiveJob args deleted before the job runs raise `DeserializationError` (job discarded) — no manual guard needed.
- **Dead** — value derived within the same scope/query (org id pulled from the rows you're iterating), or a column always set at creation with no nullify FK and no code path that clears it. Remove these.

The cross-check the user asks for ("how do other items handle this?") is to find whether a sibling has the nullify FK / deletion path that justifies the guard — not a blanket "keep all nil safety". See [[feedback_membership_references]], [[project_sectel_inbox_dual_pipeline]].
