# Verify cursor timestamp round-trip precision

Proves the `pre_serialize` fix for the inbox keyset cursor.

`01-roundtrip.rb` takes a Time with sub-millisecond microseconds and shows:
- default `.to_json` (pagy's path without `pre_serialize`) truncates to milliseconds → usec lost
- `iso8601(6)` (what `pre_serialize` writes) → `type_for_attribute(:created_at).cast(...)`
  (what pagy's `typecast` does on decode) round-trips the exact microseconds

Run:

    bin/rails runner .solve/tasks/2026-07-08-cursor-precision-roundtrip/01-roundtrip.rb

Verify: the `iso8601(6)` cast-back usec equals the original (77459); the `.to_json`
path drops to 77000 (millisecond-truncated).
