---
name: project-load-console-logger-leak
description: "Rails.application.load_console in a test permanently broadcasts Rails.logger to STDERR, spamming the whole suite with SQL"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8bceb75d-e945-4f27-a93f-372d71f344c7
  modified: 2026-08-11T10:42:57.422Z
---

`test/local/fixture_console_helpers_test.rb` calls `Rails.application.load_console` in `setup` to load the untracked console-helper initializers. That runs **every** registered `console do … end` block, including ActiveRecord's (`active_record/railtie.rb`), which does `Rails.logger.broadcast_to(ActiveSupport::Logger.new(STDERR))` and never removes it. `capture_io` cannot suppress it — the sink holds the real `STDERR` object, not `$stderr`.

Result: from that point on the worker prints all `:debug` output to the terminal — SQL, `Started GET`, `Processing by`, and the `----- TestName -----` banners from `ActiveSupport::Testing::TaggedLogging`. Rails parallelizes by **test, not by file**, so all 17 tests land in different workers and nearly the whole suite goes noisy. Measured: 12,620 lines of output → 13 after the fix.

Fix lives in that file's `setup`:

```ruby
Rails.logger.silence { capture_io { Rails.application.load_console } }
Rails.logger.broadcasts.each do |sink|
  Rails.logger.stop_broadcasting_to(sink) if ActiveSupport::Logger.logger_outputs_to?(sink, $stderr, $stdout)
end
```

`silence` suppresses the one-off `Current.set_from_membership` hint that `multi_tenancy_console_hint.rb` logs while the sink still exists. Guarded by a regression test in the same file asserting `logger_outputs_to?(Rails.logger, $stderr, $stdout)` is false.

`load_console` also leaks, unfixed and accepted: `ActiveRecord.verbose_query_logs = false`, `ActiveRecord::Base.attributes_for_inspect = :all`, the IRB completor prepends, and `TOPLEVEL_BINDING` extensions.

Related: [[project-local-helpers-manual-worktree-sync]], [[project_migration_scope_guard]]
