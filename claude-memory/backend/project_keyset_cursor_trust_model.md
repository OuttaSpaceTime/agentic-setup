---
name: project-keyset-cursor-trust-model
description: Keyset cursors are trusted because we mint them; decode checks sort identity plus a nil guard that normalized columns slip past
metadata: 
  node_type: memory
  type: project
  originSessionId: 2ab54d45-9ab9-4fdc-8bd7-07c35b79cba6
  modified: 2026-10-02T06:50:56.088Z
---

**Current state on the stacked series `1123-keyset-2…6` (verified 2026-10-02):** every bad cursor raises `KeysetPagination::NotSeekable`, which IS registered in `lib/action_json_api/error_responses.rb` → 422 "Page[after] could not be decoded", `source.parameter` `page[after]`; the railtie puts it into `rescue_responses`, and `ErrorsController` derives its kinds from that registry (no per-error mapping there). The cursor carries `sort` (incl. the `-` prefix), so a sort switched mid-walk *and* a direction flip are both refused. Covered by the `refuses …` tests in `test/integration/api/v2/keyset_pagination_test.rb` and `'not_seekable' => 422` in `errors_controller_test.rb`. The rest of this note describes the older `be-1123-4-keyset` design.

On main (merged from the 1123 keyset stack; originally built on `be-1123-4-keyset`, 2026-09-21) the keyset pagination code was rebuilt around the
assumption that a `page[after]` cursor was minted by us. `openapi/info.yml:71` already states clients
must not construct one by hand, so `Keyset::Cursor.decode` checks the sort identity and that no cast
value is `nil` — a mismatch, bad base64, non-JSON, a hash or a bracket-nested param all raise
`Keyset::InvalidCursor` (one 422). Value decoding is `ActiveRecord::Type#cast` via
`Keyset::Column#cast`; the four hand-written decode branches and the per-value `ArgumentError` are
gone.

**A `null` in the cursor is refused in 39 of 52 sort positions, and harmlessly coerced in the other
13.** `normalizes` wraps the attribute type in
`ActiveModel::Attributes::Normalization::NormalizedValueType`, so
`Component.type_for_attribute('name').cast(nil)` returns `""`, not `nil`, and `cast.none?(&:nil?)`
has nothing to refuse. The 13 are every `normalizes_to_empty_string` column: `Component`
name/version/vendor/url/deactivation_reason, `ComponentRequest`'s five,
`Notification::Vulnerability` cve/cwe, `ApiToken#description`.

**This is not a hole — do not "fix" it without a reason.** Verified 2026-09-21: `decode` of
`["name asc, id asc", null, 1]` and of `["name asc, id asc", "", 1]` both return `["", 1]` and yield
byte-identical pages. No NULL ever reaches the tuple, so the guard's stated goal (never bind NULL,
never return a confusingly empty 200) still holds; the cast achieves it instead of the raise. `""` is
a legitimately minted cursor value on those columns anyway, so a forger gains nothing. The only
difference is that `null` gets a valid 200 rather than a 422. JSON itself keeps `""` and `null`
distinct — the collapse is in `Keyset::Column#cast`, not the encoding. The always-appended `id`
tiebreaker casts `nil -> nil`, so a cursor null in the id position is always refused.

**The `cast.none?(&:nil?)` guard fires on nothing we mint — it is a cheap assertion against a
silent failure, not a defence against clients.** Verified 2026-09-21: 15,806 encode/decode round
trips (every sort key, both directions, every seeded record, all 10 paginated models) produced 0
nils. `seekable?` already guarantees the source value is never null, and `Cursor.encode`'s infinity
sentinel and `iso8601(6)` cover the lossy-JSON cases. Keep the guard anyway: if a nil ever did
arrive it binds as NULL, `(col, id) > (NULL, n)` matches no row, and the endpoint returns a 200 with
an empty page instead of an error — silent, so worth one cheap check.

**The "deploy repoints a sort key" route does not actually reach it.** The identity string is built
from the *mapped* column name, so repointing `version` from `version_info` to another column shifts
the identity and the stale cursor is refused by the identity check before any cast. The only
remaining route is the same column changing type in a migration while cursors are in flight, and it
must change *to* date/datetime/uuid to yield nil — integer and float casts fall back to `to_i`/`to_f`
(`Float#cast("abc") == 0.0`).

**Do not rewrite the comment on `cursor.rb` to blame malformed client input.** Tried 2026-09-21 and
reverted: `openapi/info.yml:71` already disclaims hand-built cursors, so framing the guard around
"an unparseable value" justifies it with the one scenario we do not care about. The original
cause-neutral wording ("A nil compares as NULL in the tuple, so the page would come back empty
rather than refused") is correct and stays.

**Accepted trade-off:** a payload with a *valid current identity* but an edited body is not rejected.
Only reachable by forging, which the spec disclaims.

**`Keyset::Columns::NotSeekable` is not client-reachable and is not in the error registry**
(`lib/action_json_api/error_responses.rb`), so it would be a 500. The only trigger left after the
NOT NULL migration is mixed sort directions, and every endpoint's OpenAPI `sort` is a single-value
enum — `sort=name,-vendor` is a 422 `OpenapiFirst::RequestInvalidError` before the model sees it.

**Verified empirically, do not re-derive:** `type_for_attribute(:id).cast('42abc') == 42`;
`cast('infinity')` on a date column → `Float::INFINITY`; `cast('not-a-date')` → `nil`;
`[Float::INFINITY].to_json` → `"[null]"` silently, and `TimeWithZone#to_json` drops sub-second
precision — which is why `Cursor.encode` still maps infinity to a string sentinel and times to
`iso8601(6)`. The identity check also subsumes arity and non-array payloads, since
`identity, *values = JSON.parse(...)` on a scalar or hash leaves a non-keyset identity.

Related: [[project-keyset-sort-seed-scripts]], [[feedback-no-pass-through-collaborators]],
[[reference-openapi-discriminator-stack]]
