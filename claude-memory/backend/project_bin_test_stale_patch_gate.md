---
name: project-bin-test-stale-patch-gate
description: coverage/coverage.json is now written by the test run itself; before 2026-09-21 nothing regenerated it and the patch gate read week-old data
metadata:
  type: project
---

`bin/patch_coverage` and `bin/test` both gate on `coverage/coverage.json`, which only
`SimpleCov::Formatter::JSONFormatter` writes. Until 2026-09-21 `test/test_helper.rb` set
`SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter` alone, so nothing regenerated that
file — on branch be-1123-4-keyset it was 7 days old (seeded by copying `coverage/` from main) and
the gate reported 79.53% patch coverage over lines the run had actually covered, plus four
"changed beyond the N-line entry (is the report stale?)" warnings. The GitLab `patch_coverage` job
had the same hole (it is `allow_failure: true`, so nobody noticed).

Fixed on be-1123-4-keyset by making the formatter a MultiFormatter of Cobertura + JSONFormatter.
Same run, real numbers: 100.00% (222/222) lines after the fixes.

**How to apply:** if the patch gate's verdict ever looks wrong again, check
`ls -l coverage/coverage.json` against `coverage/.resultset.json` — they should now share a
timestamp. Related: [[project_worktree_coverage_seeding]], [[feedback_test_output]].
