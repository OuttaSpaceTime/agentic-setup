---
paths:
  - "**/*.rb"
  - "**/*.erb"
---

# Minimal Comments

## Requirements

- **Almost no comments.** Default to none.
- Comments ONLY for:
  - Edge cases that diverge from general flow
  - Non-obvious fixes/workarounds
  - Complex algorithms where intent isn't clear
- When one of the above genuinely applies, keep it to **1–2 lines max** — never a paragraph or a comment block.

<example>

```ruby
# Temporarily bypass scoping due to legacy data migration
Current.without_organization_and_membership_scopes { ... }

# This format string quirk is specific to ActionMailer
mail(subject: "Subject: #{name}")
```

</example>

<example type="invalid">

```ruby
# Get the user's membership
membership = user.membership

# Update the monitoring list
monitoring_list.update!(name: new_name)

# Send email to subscribers
recipients.each { |r| mailer.deliver_later }
```

</example>

<critical>

  - Do NOT remove comments that explain why a non-obvious fix was added
  - Do NOT add comments that restate what the code does
  - Do NOT reference ticket/issue numbers in comments — that history lives in git/PRs, not the code. Let a descriptive test name or method name carry the intent instead.

</critical>
