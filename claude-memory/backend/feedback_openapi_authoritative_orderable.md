---
name: feedback_openapi_authoritative_orderable
description: openapi/paths/*.yml decides which orderable_columns/order_mapping entries stay; orderable_columns doubles as the dynamic_where filter whitelist
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8504773e-c6fb-49f6-94f3-5d3eef666f71
  modified: 2026-08-11T10:55:36.840Z
---

The `openapi/paths/*.yml` files are the authoritative source for what to keep in a model's
`orderable_columns` / `order_mapping`. Every v2 request runs through
`RequestSchemaValidation#validate_request!` (`OpenapiFirst.load(openapi/openapi.yml)`, `raise_error: true`)
before the controller, so a `sort` value outside a path's enum returns 422 and can never reach the model.

**Why:** that makes "is this sort key in the openapi enum?" a decidable test for dead code, instead of guessing
about frontend usage.

**How to apply:** before deleting an entry, check BOTH sides of the spec — an `orderable_columns` entry can be
alive as a *filter* even when it is not sortable, because `Orderable#dynamic_where` raises
`Invalid column X in .dynamic_where` unless `orderable_columns.include?(column)`. Component `active` /
`end_of_life`, MonitoringList `comment` and ComponentRequest `prioritized` are filter-only survivors.
Probe reachability with a throwaway integration test that GETs `?sort=<camelCaseKey>` and prints the status
(422 = dead, 200 = live). Note `relevance` returns 422 without `filter[search][is]` yet is still live.

`getter_mapping` / `readable_columns` only feed cursor pagination — `read_external` is called nowhere but
`Paginator::JsonApiCursor` — so a getter entry whose key is not in `readable_columns & orderable_columns`
is dead too.

