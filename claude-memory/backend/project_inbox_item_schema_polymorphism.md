---
name: project_inbox_item_schema_polymorphism
description: "Per-itemable-type inbox item OpenAPI schema (plain oneOf, 15 per-type files) — built 2026-07-09 but NEVER LANDED: branch gone, not on main (checked 2026-10-28)"
metadata: 
  node_type: memory
  type: project
  originSessionId: adef8bf3-8165-4d42-a5ab-8bb20260d954
---

Goal: replace the single flat `vilocifyInboxItem.yml` (whose `attributes` object has ZERO required props — every itemable field optional to let ~14 `itemType` variants validate) with per-itemable-type schemas so each declares its OWN required attributes. Builds on branch `1084-...` (which already introduced the proper `Inbox::Item::MembershipExpirySummary` schema + the plain-`oneOf` entry precedent).

**Status (2026-10-28): never landed.** Branch `inbox-items-yml-inheritance` no longer exists and no commit on any branch contains the per-type files; main still has the single flat `vilocifyInboxItem.yml`. The reasoning below still applies if the split is picked up again.

**Earlier status (2026-07-09): BUILT pre-3.1** on branch `inbox-items-yml-inheritance` (ff'd onto 1084 `40d05bebd`). Reversed the earlier postpone — Felix chose to build now. Only the DETAIL view `vilocifyInboxItem.yml` split; list/summary stays uniform. 15 self-contained per-type files in `openapi/components/schemas/inboxItemAttributes/` (generic=5 desc-only, monitoring-list=8 +monitoringListId, notification=1 +monitoringListName, membershipExpirySummary=1); `attributes` → `oneOf` of 15 `$ref`s; relationships+envelope untouched. 15 individual tests in new `Api::V2::Inbox::ItemsController::SchemaConformanceTest`. Verified: lint+rubocop+editorconfig clean, 44 tests green, oasdiff clean (inbox is internal-only, not in v2.yml), enum-partition exact. NOT committed (Felix commits). `redocly bundle` regenerated internal.yml.

Deferred to post-1065/3.1 (see [[reference_openapi_discriminator_stack]]): base-attribute sharing via allOf+unevaluatedProperties; `nullable:true`→`type:[x,'null']` sweep on organizationName+monitoringListId (silent-null trap if left as-is under 3.1); discriminator (inert, documented in todo.md). 1065 migrates spec 3.0.2→3.1.0 and heavily churns internal.yml.

**Design locked: PLAIN `oneOf`, NO discriminator** (see [[reference_openapi_discriminator_stack]] for why — discriminator is inert across all 3 consumers).

**Ready-to-execute plan when 1065 (and 1084) are in main:**
- Backend: `attributes` in `vilocifyInboxItem.yml` → `oneOf` of ~14 per-type `$ref` files (one per `itemType`). Each file: `type: object`, `additionalProperties: false`, `required: [itemType, ...type-specific]`, `itemType: {enum: [<one value>]}`, `title: <itemType>` (openapi-explorer's only label lever), 3.1 null syntax. Derive per-type required attrs from each of the 10 `Inbox::Itemable` models' serializers. Consider moving `relationships` (inboxNotificationEntries / inboxMembershipExpiryEntries) into the per-type variants too. Mirror the `itemType` enum in `vilocifyInboxItemSummary.yml`.
- Validate: `redocly bundle` (never `--dereferenced`), `bin/openapi-diff`, `bin/oasdiff` (will flag newly-required fields as breaking — review/whitelist via `.oasdiff_*_ignore`), `bundle exec rake action_json_api:lint`.
- Frontend: branch off `592-admin-summary-inbox-item-page-renders-the-body-from-json` (HEAD `5aee5639`, in repo `vilocify-frontend`). It ALREADY hand-writes the discriminated union keyed on `attributes.itemType` (`src/app/shared/jsonapi/resources.ts`) and switches on it everywhere. Wire shape doesn't change → no parsing changes needed. Only alignment: tighten per-variant optionals that become required; move `monitoringListName/Id` out of shared `InboxItemBase` into allowed variants; keep `INBOX_ITEM_TYPES` (`inbox.component.ts`) + `inboxItemTypeToTitle` (`inbox-card.component.ts`) matching the backend enum values.

Full research output: two workflows in session adef8bf3 (json_schemer probe, canonical practice, redocly bundle, frontend, version-delta, openapi-explorer docs).
