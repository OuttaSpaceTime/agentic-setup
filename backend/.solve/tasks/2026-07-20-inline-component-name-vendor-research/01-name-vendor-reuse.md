# 01 — Name & Vendor reuse (two queries)

Measures how much `Component::Name` / `Component::Vendor` are actually reused, as two
plain AR group-counts over `Component`. Prints, per table: how many distinct
names/vendors are in use and how many are shared by more than one component.

Run (development DB):
    bin/rails runner .solve/tasks/2026-07-20-inline-component-name-vendor-research/01-name-vendor-reuse.rb

For the fixture dataset instead, prefix `RAILS_ENV=test`.

Verify: the two "reused" counts should match the tallies we grepped from the fixtures
(names: 6 of 9 reused; vendors: 5 of 7 reused) when run under `RAILS_ENV=test`.
