# 02 — Attribute usages of Component::Name / Component::Vendor

Greps `app` + `lib` for every column on the two dedup tables so you can scan which
are actually read vs only written by sync. Distinctive columns (`abbreviation`,
`sec_url`) are grepped raw; noisy ones (`name`, `url`, `active`) are anchored to a
`component_vendor.` / `component_name.` / `vendor.` receiver to cut false hits.

Run:
    bash .solve/tasks/2026-07-20-inline-component-name-vendor-research/02-attribute-usages.sh
