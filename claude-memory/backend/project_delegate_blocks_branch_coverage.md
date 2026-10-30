---
name: project_delegate_blocks_branch_coverage
description: "Rails `delegate` generates branches that can never be hit, so a changed delegate line can never reach the 100% branch patch-coverage gate"
metadata:
  node_type: memory
  type: project
  originSessionId: db411b36-859f-4bf5-8918-ecb0cdbdc2a0
  modified: 2026-10-22T14:50:54.551Z
---

Measured 2026-09-22 (activesupport 8.1.3.1, simplecov 1.3.0, Ruby 4.0.6).

Why the branches exist: `delegate` without `allow_nil` generates a body whose `if` sits **inside a
rescue handler**, so on the happy path neither arm runs — "branch missed, branch missed" on the
`delegate(...)` line, 0/2:

```ruby
"def #{method_name}(#{definition})" << "  _ = #{receiver}" << "  _.#{method}(#{definition})" <<
"rescue ::NoMethodError => e" << "  if _.nil? && e.name == :#{method}" << …
```

`allow_nil: true` generates the other form, `if !_.nil? || nil.respond_to?(:m)`, whose then-arm does
get hit — 1/2, still short of 100%.

Why they are measured at all: SimpleCov only records eval-generated code when eval coverage is on,
and `test/test_helper.rb` turns it on **implicitly** — `cover_views` calls `enable_eval_coverage`
internally. A bare `SimpleCov.start { enable_coverage(:branch) }` records no branches for a delegate,
which makes the problem look absent when probing outside the suite.

The gate: `bin/patch_coverage` is `simplecov patch --base main --minimum 100`, and its gate is
`%i[line branch method].any? { |criterion| short?(…) }` — branches included, changed lines only. The
19 existing `delegate(` lines in `app/`/`lib/` are therefore fine until someone edits one.

The fix Felix picked, which `rubocop --only Rails/Delegate` does not match and which generates no
branches at all:

```ruby
def count(...) = @columns.count(...)
```

Note `rubocop -A` autocorrects the plain `def count = @columns.count` straight to `delegate`, so the
`(...)` forwarding is what makes it stick.

Rejected: disabling eval coverage (`view_coverage?` requires it, so ERB coverage would go with it);
`allow_nil: true` (1/2); tests covering the rescue arms (they test Rails' own guard — you would need
a nil target *and* a `NoMethodError` with a different name); `# :nocov:` (same family as an inline cop
disable, see [[feedback_rubocop_disable]]).

Update 2026-10-22 (branch 1192, `User::Login`): Felix chose to keep `delegate` and add
`# simplecov:disable branch` (simplecov 1.3.0 directive, inline or `disable`/`enable` block form) —
measured 12/12 branches, line and method coverage still counted. Rejected Forwardable: its generated
methods are evaled under `forwardable.rb` so they drop out of the report (not covered, just
invisible), and `extend(Forwardable)` shadows Rails' `delegate` — `include(ActiveModel::Validations)`
after it crashes with `wrong number of arguments (given 2, expected 1)`. `delegate` under a bare
`private` stays public; use `private: true`.

Related: [[project_bin_test_stale_patch_gate]], [[reference_migration_invoke_change_only]].
