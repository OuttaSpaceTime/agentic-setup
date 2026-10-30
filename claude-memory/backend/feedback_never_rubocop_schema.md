---
name: feedback-never-rubocop-schema
description: "Never pass db/schema.rb to rubocop -A — it's Excluded and gets fully reformatted"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3b901b56-a4a3-4e72-8869-4049db1dbf25
  modified: 2026-10-28T08:16:32.738Z
---

`db/schema.rb` is listed in `.rubocop.yml` global `Exclude`. If you pass it explicitly to `bundle exec rubocop -A db/schema.rb`, RuboCop ignores the exclude (explicit args override it) and reformats the ENTIRE auto-generated file (~3500 corrections, e.g. `create_table "x"` → `create_table('x')`), producing a massive unwanted diff.

**Why:** schema.rb is auto-generated and intentionally kept in its default `db:schema:dump` style; reformatting it churns the whole file.

**How to apply:** Never edit schema.rb by hand; `bin/rails db:migrate` regenerates it (since 2026-10-15 the team's `.opencode/plugins/protected-files.js` blocks hand edits). Never include it in a rubocop invocation. If you already did, `git checkout db/schema.rb` and rerun `bin/rails db:migrate`. Same caution for any auto-generated file in the Exclude list. Related: [[feedback_rubocop_disable]].
