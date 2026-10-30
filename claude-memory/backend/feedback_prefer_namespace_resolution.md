---
name: feedback_prefer_namespace_resolution
description: Prefer Rails namespace resolution for associations — drop class_name whenever Rails can derive the class; only keep it when the association name is intentionally different from the class name
metadata: 
  node_type: memory
  type: feedback
  originSessionId: dc422e05-56a4-4a07-a636-4d89543e2fb5
---

Drop `class_name` on any association where Rails can resolve the target class through namespace inheritance. Only keep it when the association name is a deliberate alias that doesn't match the class (e.g. `belongs_to :event` pointing at `MonitoringList::NotificationRevisionEvent`, or `has_many :items` pointing at `NotificationRevisionItem`).

**Why:** Redundant `class_name` strings are noise — they drift when classes are renamed and obscure what convention already guarantees. The only legitimate reason to keep one is a better or shorter association name that can't be derived.

**How to apply:** For each `class_name:` option, ask: if I removed it, would Rails find the right class via namespace walk (inner → enclosing → root)? If yes, remove it. If the association name is a deliberate human-readable alias (and removing `class_name` would break resolution), keep it. See [[feedback_belongs_to_namespace_defaults]] and [[feedback_table_name_length]].
