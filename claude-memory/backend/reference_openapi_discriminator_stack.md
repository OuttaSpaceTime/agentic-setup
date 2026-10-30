---
name: reference_openapi_discriminator_stack
description: "On Vilocify's OpenAPI stack, `discriminator` is inert across all 3 consumers — repo idiom is plain oneOf; plus the 1065 3.1 nullable trap"
metadata: 
  node_type: memory
  type: reference
  originSessionId: adef8bf3-8165-4d42-a5ab-8bb20260d954
---

Empirically verified (2026-07-09) for polymorphic response bodies (e.g. inbox items — see [[project_inbox_item_schema_polymorphism]]). Canonical shape is **plain `oneOf` of per-type schemas, each `additionalProperties: false` + own `required` + an `itemType` enum-of-one — NO discriminator.** Why discriminator buys nothing here:

- **Validator (json_schemer 2.4.0 AND 2.5.0):** discriminator IS an active keyword even in 3.0 mode (OpenAPI30 vocab inherits OpenAPI31's `Discriminator`) — but for a disjoint-enum `oneOf` it adds ZERO pass/fail strictness, only marginally cleaner errors. A doc with the right `itemType` but a missing required field already matches 0 branches → fails. Costs: every branch must be a `$ref` (inline branches raise `KeyError: "$ref"`); implicit mapping FAILS valid docs (snake_case `itemType` ≠ camelCase schema names) so an explicit mapping is mandatory; it also drops the "exactly one branch" mutual-exclusivity check. Byte-identical validation across both gem stacks + both dialects.
- **Docs (openapi-explorer, our actual UI — served version 2.4.784, not the `^2.2.764` floor):** `grep discriminator` = ZERO matches in all dist builds → completely ignored. `oneOf` renders as a "ONE OF" group; without labels branches show as anonymous "1/2/3". The ONLY label lever is `title:` on each branch (renders "1  ml_notification"). Redoc/Swagger-UI DO honor discriminator, but they aren't our renderer. Inbox schema only renders under `/documentation?name=internal.yml`.
- **Frontend (Angular `vilocify-frontend`):** NO OpenAPI→TS codegen exists — types are hand-written (`src/app/shared/jsonapi/resources.ts`). So a discriminated-union generator would benefit, but nothing consumes the spec. Discriminator buys the frontend nothing.

Migrating plain oneOf → discriminator LATER is one additive commit IF variants are already separate `$ref` files — but you almost never will, since nothing benefits.

`allOf` inheritance (base + per-type extension) is a NON-STARTER: the repo sets `additionalProperties: false` everywhere, which conflicts with `allOf` (branches validate independently → base rejects child props).

**1065 3.1 trap:** branch `1065-update-openapi_first-gem` flips spec to OpenAPI 3.1.0. Under 3.1, a leftover `nullable: true` is treated as an unknown annotation and `null` values get REJECTED (json_schemer enforces the bare `type`). Any 3.0-syntax `nullable` authored before 1065 silently breaks after it. Also: never combine `unevaluatedProperties` with `discriminator` before json_schemer 2.5.0 (2.4.0 bug false-rejects — PR #220). Treat `public/openapi/internal.yml` as generated: resolve conflicts by re-bundling, not by hand.
