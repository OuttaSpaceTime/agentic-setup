---
paths:
  - "app/**/*.rb"
  - "config/**/*.rb"
  - "lib/**/*.rb"
  - "test/**/*_test.rb"
  - "db/**/*.rb"
---

# Run Quality Tools

## Requirements

After generating or modifying Ruby code or configuration files:

1. `bin/rubocop -A` — lint and autoformat Ruby
2. `bin/test <every file you edited>` — run the tests covering your change and gate its patch coverage (do NOT pipe output)
3. `bin/quality` — reek, flay and flog
4. `bin/test --affected` — once, before you hand the work back

The `gate-runner` agent (`.claude/agents/`) runs steps 1-3 with full output and returns the
failures and a triage of every `bin/quality` finding; delegate to it instead of skipping a step.

Run steps 1-3 after every task that modifies code, not only at the end of a multi-step task. Run
step 4 once for the whole change: it nearly always runs the whole suite, so after every task it
costs the full suite for little, but it is what catches a break in a test the scoped runs never
selected (a fixture change breaking a serializer test). A task is not complete until the tests pass
and every `bin/quality` finding is reported as described in
`802-quality-findings.md`.

Include the outcome of every command in the response.

## Check the blast radius before you edit

Before changing an `app/`/`lib/` file, ask the map what it impacts:

```
bundle exec simplecov tests app/models/membership.rb --input coverage/map/coverage.json
```

It lists every recorded test — `test/file.rb:line` — that executes that file. Use it to size a
change before making it: nine test files means a contained edit, ninety means the change reaches
most of the suite and deserves more care. It is also how you find the non-obvious tests that
exercise the code without naming it, which is exactly what `bin/test` then runs for you.

Strip the `:line` suffix and dedupe to see just the files:

```
bundle exec simplecov tests app/models/membership.rb --input coverage/map/coverage.json | sed 's/:[0-9]*$//' | sort -u
```

## bin/test

Pass every file you just edited — the `app/`/`lib/` files **and** the test files:

```
bin/test app/models/user.rb app/models/membership.rb test/models/user_test.rb
```

- An `app/`/`lib/` argument selects the recorded tests of the **methods** you changed: each line
  changed against `main` → its enclosing method → every test that runs that method. A changed
  line outside any method (`has_many`, a callback, a constant) selects all recorded tests of the
  file. The patch-coverage report is filtered to exactly the files you named.
- Every `*_test.rb` changed on the branch or untracked runs too, named or not.
- A new method or file has no recorded tests yet, so it is reached only by the tests you name or
  changed. Only when nothing at all is selected does `bin/test` fall back to the named files'
  recorded tests, then to the whole suite.
- Naming an `app/`/`lib/` file that is unchanged against `main` selects all of its recorded tests.
- Only test files named: the tests run and the gate is skipped (`gate skipped - no app/lib files
  named`), because a partial run cannot judge the coverage of the whole branch.
- No arguments runs the whole suite and gates every line the branch changed.
- A failing test aborts the run before the map is recorded and before the gate, so a red run
  reports no coverage.
- Test filters are refused: `-n`, `--name`, `file:line` and `file:3-5` exit with an error. Iterate
  on one test with `bin/rails test file:line`, then confirm with `bin/test`.
- `--affected` takes no paths and exits with an error when given some: it finds the changed files
  itself.
- Any other path (a fixture, a `test/support/` file, `config/`) is skipped with a note. If that
  leaves nothing selected, the whole suite runs, without a gate.

The gate is 100% patch coverage of the lines the branch changed against `main`. A non-zero exit
means changed lines are uncovered — add tests, never lower the gate.

`main` is the default base: `bin/test` reads it from `CI_MERGE_REQUEST_DIFF_BASE_SHA`, for test
selection, the gate and `--affected` alike. On a stacked branch, `main` pulls in the parent
branches' lines too; compare against the parent instead with
`CI_MERGE_REQUEST_DIFF_BASE_SHA=<parent-branch> bin/test <files>`.

`--affected` works per file instead, and any changed file outside `app/`/`lib/` (`config/`,
`db/`, fixtures, `test/support/`, `openapi/`) makes it run the whole suite — which is why it runs
once, at the end.

### A partial run's verdict is sound, never optimistic

Coverage only ever grows as more tests run, so a scoped run's test set being a subset of the whole
suite's means its coverage is a subset too. That fixes the direction of every possible error:

- **green on a partial run ⇒ green on the full suite.** Running more tests cannot take coverage
  away, so a pass is trustworthy and needs no confirmation by a wider run.
- **red on a partial run may be pessimistic** — the run may simply not have included a test that
  covers the line.

Verified: a 235-test scoped run and the 2389-test full suite reported the same
`75.00% (3/4) lines, 50.00% (1/2) branches` on the same change, naming the same missing line.

This holds for coverage, not for test results: a test outside the selection can still fail, and
only the `--affected` run at the end shows it.

Each run's coverage must therefore come from that run alone, which is why `bin/test` clears
`coverage/.resultset.json` first. SimpleCov merges results by `command_name` within
`merge_timeout`, so a run using fewer subprocesses than the last one would otherwise inherit its
stale workers — an 8-test run once reported 94.76% line coverage instead of its own 45.43%. Stale
coverage fails toward green, which is the one direction a gate must never fail in.

### The test map

Resolving an `app/` file to its tests needs `coverage/map/coverage.json`, recorded under SimpleCov's
`track_tests`. Every `bin/test` run records it, and the map accumulates:

- a **scoped** or `--affected` run merges what it learned into the existing map, so nothing the
  map already knew is lost
- a run of the **whole suite** — `bin/test` with no arguments, or a scoped run that fell back to
  it — replaces the map outright, which is also what prunes entries for tests that no longer exist
- a run that recorded no per-test contexts (`.simplecov` missing) aborts with `no per-test contexts
  recorded` and leaves the map as it was

The map accumulates where coverage must not, because the two make different claims. Coverage says
"this line runs now" — stale data there vouches for code nothing executes. The map only says
"these tests have touched this file", and it never contributes a number to the verdict; it decides
only which tests to run. So a stale entry costs a wasted test run, not a wrong answer.

An incomplete map under-selects: if it has never seen the tests that cover a file, `bin/test` runs
fewer of them than it should. That fails in the safe direction — fewer tests means less coverage
means a **false red**, never a false green — but it wastes your time. Run `bin/test` with no
arguments to complete and prune the map when the resolved test list looks too short.

A method is looked up in the map by name, so a map recorded before your edits shifted its lines
still finds its tests. An entry pointing at a deleted test file is dropped instead of handed to
`bin/rails test`.

<critical>

  - Never verify with `bin/rails test` directly — it records neither the test map nor patch
    coverage. Use it only for a throwaway single-test iteration.
  - A new method's `def` line counts as covered because eager loading executes class bodies, so a
    wholly untested method reports ~50%, not 0%. Trust the non-zero exit, not the percentage.

</critical>


<example>

Edited app/models/user.rb and test/models/user_test.rb. Ran rubocop (0 offenses),
`bin/test app/models/user.rb test/models/user_test.rb` (235 runs, 0 failures, patch coverage
100.00% (2/2) lines), `bin/quality` (reek 0 warnings, flay clean, flog clean). Before handing
back: `bin/test --affected` (2389 runs, 0 failures).

</example>

<example type="invalid">

Delivered updated Ruby code without running quality tools.

</example>

<example type="invalid">

Ran `bin/rails test test/models/user_test.rb` and reported the change as verified — no patch
coverage was gated.

</example>

<example type="invalid">

Ran `bin/test` with no arguments after editing two models, so the report covered the whole diff
instead of the files just edited.

</example>
