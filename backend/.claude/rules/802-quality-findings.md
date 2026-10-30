---
paths:
  - "app/**/*.rb"
  - "config/**/*.rb"
  - "lib/**/*.rb"
  - "test/**/*_test.rb"
  - "db/**/*.rb"
---

# Report Every bin/quality Finding

## Requirements

After the final `bin/quality` run of a task, present **all** findings — reek, flay and flog — never
a filtered subset. Start with a short index table (`#`, finding, origin, verdict) so the developer
can pick, then give every finding its own block — never squeeze the explanation into table cells:

- **Finding** — tool, smell name and `file:line` as printed.
- **Rule** — what the check detects, the threshold that applies (from `.reek.yml` or the tool
  default), and why it counts as a problem, in plain language. For reek the linked `docs/*.md`
  page is the source; for flay, what counts as duplication; for flog, what the score measures.
- **Why it fires here** — the concrete construct in this code that trips the rule: name the
  variable, call, branch or duplicated node and quote the offending lines. "Refers to `subscriber`
  4 times, `self` once" — not a restatement of the rule.
- **Origin** — introduced by this task, or pre-existing in code the task did not touch.
- **Verdict** — Fix or Leave, decided by you, with a one-line reason. Judge against the project
  rules: a fix that adds an abstraction, a pass-through object or indirection only to silence a
  smell is worse than the smell.
- **Sketch** — a small before/after snippet of the change that would resolve it, for Leave
  findings too. Only a pure move or rename may be a sentence instead.

Do not apply the fixes in the same turn; the list is a proposal the developer picks from.

<example>

| # | Finding | Origin | Verdict |
|---|---------|--------|---------|
| 1 | reek FeatureEnvy `app/models/membership.rb:42` | this task | Fix |

**1. reek FeatureEnvy — `app/models/membership.rb:42` `Membership#notify`**

- **Rule:** fires when a method refers to another object more often than to `self`. The method's
  logic is about that other object, so it likely belongs there — and every change to that
  object's shape now also has to touch `Membership`.
- **Why it fires here:** `notify` reads `subscriber` four times (`subscriber.email`,
  `subscriber.locale`, `subscriber.muted?`, `subscriber.name`) and `self` only once.
- **Origin:** this task.
- **Verdict:** Fix — nothing in the method needs membership state beyond handing over itself.
- **Sketch:**

  ```ruby
  # before
  def notify
    return if subscriber.muted?

    Mailer.notify(subscriber.email, subscriber.name, subscriber.locale, self).deliver_later
  end

  # after
  def notify = subscriber.notify(self)

  # Subscriber
  def notify(membership)
    return if muted?

    Mailer.notify(email, name, locale, membership).deliver_later
  end
  ```

</example>

<example type="invalid">

| 1 | reek FeatureEnvy `Membership#notify` | The method reads `subscriber` more than `self` | this task | Fix | Move it to `Subscriber` |

</example>

<example type="invalid">

`bin/quality`: reek 3 warnings (mostly noise), flay clean, flog clean.

</example>
