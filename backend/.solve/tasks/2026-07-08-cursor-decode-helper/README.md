# decode(cursor) helper

`decode.rb` defines a top-level `decode(cursor)` that turns a pagy keyset
`page[after]` token back into the JSON value array. It mirrors pagy's
`Pagy::B64.urlsafe_decode` re-padding, so no Rails/pagy needs to be loaded.

## In rails console / irb

    load '.solve/tasks/2026-07-08-cursor-decode-helper/decode.rb'
    decode("WyIyMDI2LTA3LTA4VDEyOjAwOjAwLjI5OTk5OVoiXQ")
    # => ["2026-07-08T12:00:00.299999Z"]

## Straight from the shell (no Rails boot)

    ruby -r./.solve/tasks/2026-07-08-cursor-decode-helper/decode.rb -e 'p decode(ARGV[0])' "WyIy...="

## Note

Pagy already ships `Pagy::Keyset.decode(cursor)` — usable in rails console once
pagy is loaded. This helper is the standalone equivalent for quick terminal use.
