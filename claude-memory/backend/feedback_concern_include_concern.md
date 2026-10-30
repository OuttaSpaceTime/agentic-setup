---
name: feedback_concern_include_concern
description: "One ActiveSupport::Concern including another — use body-level include(), not included do"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 57b6145c-dc63-4baf-9ff8-1324be506fa3
---

When an `ActiveSupport::Concern` needs to pull in **another** Concern, put `include(OtherConcern)` at the **module body level** — NOT wrapped in `included do ... end`.

**Why:** ActiveSupport::Concern has a dependency mechanism. A body-level `include(OtherConcern)` registers it as a dependency that propagates to the host class when the outer concern is included (the other concern's `included` block and `class_methods` apply to the final class). `included do include(...) end` is only needed for **plain** (non-Concern) modules.

**How to apply:** If both modules `extend(ActiveSupport::Concern)`, write `include(Cleanup)` directly in the body. Don't reach for `included do`.

Concrete case: `Inbox::Event::Cleanup` reuses the shared `Cleanup` concern (`app/models/concerns/cleanup.rb`, which defines `cleanup_due` as `due_for_deletion.in_batches.destroy_all`) by doing body-level `include(Cleanup)` and defining its own `due_for_deletion` — mirroring `MonitoringList::NotificationRevision`. See [[project_cleanup_deferred]].
