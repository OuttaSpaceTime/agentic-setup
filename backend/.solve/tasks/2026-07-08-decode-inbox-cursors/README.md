# Decode the inbox pagination cursors from localhost.har

Base64-decode the `page[after]` cursor values seen in the HAR to inspect how many
keyset columns the cursor carries.

Run:

    ruby .solve/tasks/2026-07-08-decode-inbox-cursors/01-decode.rb

Verify: each decoded cursor is a JSON array. If it has ONE element (created_at only)
the keyset lacks a unique tiebreaker; TWO elements (created_at + id) means it is a
proper unique keyset.
