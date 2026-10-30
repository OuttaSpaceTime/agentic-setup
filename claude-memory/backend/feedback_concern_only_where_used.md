---
name: feedback-concern-only-where-used
description: "include a model concern only in the models that use it, never in ApplicationRecord to share it with a few"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 1af46a83-530a-4eea-a95b-24e8892f40f1
  modified: 2026-09-29T15:46:49.615Z
---

Include a model concern (scopes, class methods) only in the models that actually use it — never in `ApplicationRecord` just so a handful of models can reach it.

**Why:** anything in ApplicationRecord becomes public API on every model; a reviewer (Niklas) flagged exactly this for `KeysetPage` on branch 1123-keyset-2, and Felix agreed.

**How to apply:** add `include(Concern)` next to the related includes in each consuming model (e.g. right after `include(JsonApiResource)`). Don't piggyback on a bundling concern if that also pulls it into a model that doesn't use it (`JsonApiResource` also reaches `Inbox::Item`). Private class methods are not an escape hatch: a relation only delegates public class methods ([[reference-private-class-methods-relation]]).
