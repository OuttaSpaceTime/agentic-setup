---
name: fixture-model-class
description: Use _fixture model_class header when Rails can't infer the model from a non-conventional table name
metadata:
  type: feedback
---

When a model uses `self.table_name` to set a non-conventional table name (e.g., `monitoring_list_component_eol_events` for `MonitoringList::ComponentEndOfLifeReachedEvent`), Rails cannot reverse-engineer the model class from the table name. This causes fixture loading to fail: association labels go unresolved, timestamps aren't auto-filled, and UUID PKs are randomly assigned instead of deterministically.

Fix: add a `_fixture` block at the top of the YAML file:

```yaml
_fixture:
  model_class: MonitoringList::ComponentEndOfLifeReachedEvent

one:
  component: one   # now resolves via belongs_to :component
  ...
```

This enables association shorthand, auto-timestamps, and deterministic UUID PK generation — same as fixtures with conventional table names.

**Why:** Discovered when creating fixtures for `monitoring_list_component_eol_events` and `monitoring_list_component_eol_items` tables whose abbreviated names didn't map to the full model class name.

**How to apply:** Any time `self.table_name =` is set to something that doesn't follow `ModuleName::ClassName` → `module_name_class_names` convention, add `_fixture: model_class:` to the fixture file.
