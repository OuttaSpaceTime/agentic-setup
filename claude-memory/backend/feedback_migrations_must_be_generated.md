---
name: feedback-migrations-must-be-generated
description: Never hand-write migration files — always use bin/rails generate migration; match Rails version constant to Gemfile.lock
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4333181d-efd3-472c-9fdd-9daa080384ef
---

Never create a `db/migrate/*.rb` file directly with Write/Edit. Always run `bin/rails generate migration <Name> <fields>` (as a task script) so Rails assigns the timestamp/version correctly, then edit the generated file's body if needed.

Also check the `ActiveRecord::Migration[X.Y]` version matches the Rails version actually in `Gemfile.lock` — don't assume or copy it from an older migration file.

**Why:** Niklas Häusele (maintainer) flagged this in MR review: a hand-written migration (`db/migrate/20260706153340_create_membership_admin_expiry_entries.rb`) used `ActiveRecord::Migration[8.0]` while the project is on Rails 8.1, and was hand-authored instead of generated.

**How to apply:** Applies to vilocify-portal (and likely other Rails projects). Encoded as a hard rule at [[project_current_work]]'s repo in `.claude/rules/050-migrations.md`.
