---
name: rubocop-disable
description: How to silence an annoying/false-positive RuboCop cop in vilocify-portal — never inline disable
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 349daac5-d32e-4dbc-bf5d-1f911fb98f8e
---

When a RuboCop cop is a false positive or annoying to satisfy, do NOT use inline
`# rubocop:disable ...` directives. The project enables
`Style/DisableCopsWithinSourceCodeDirective` (in `.rubocop.yml`) with no allowlist,
so any inline disable is itself a rubocop offense (and there are none in `app/`/`lib/`).

**Instead, in order of preference:**
1. **Disable/scope the cop in `.rubocop.yml`** — e.g. a per-file `Exclude:` under the
   cop. Example used for the dev seeder's many keyword args:
   ```yaml
   Metrics/ParameterLists:
     Max: 16
     Exclude:
       - 'lib/database_seeder.rb'
   ```
2. **Refactor** to genuinely satisfy it — e.g. pass an options hash / value object to
   cut a long parameter list.

**Why:** Felix's explicit guidance — inline disables are banned project-wide; handle
cops at the config level or by refactoring.

**How to apply:** Don't distort code semantics just to appease a metric cop (e.g.
don't turn configurable keyword params into hardcoded constants). Prefer the config
`Exclude` for legitimate false positives; refactor when the cop has a real point.
