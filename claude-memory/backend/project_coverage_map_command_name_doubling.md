---
name: project_coverage_map_command_name_doubling
description: "bin/test's coverage/map/coverage.json doubled in size every run until it hit 4.3 GB and thrashed the machine; fixed 2026-09-14 by pinning the merged result's command_name"
metadata: 
  node_type: memory
  type: project
  originSessionId: a2c84a39-59c8-4eae-a343-bf89f0e71691
  modified: 2026-10-29T19:15:53.755Z
---

`coverage/map/coverage.json` grew **exponentially** — one run's label contained the whole previous run's label — reaching 4,540,784,596 bytes in the `be-1123` worktree on 2026-09-14. The `"total"` key did not appear until byte 4,538,237,929: the entire file was one `meta.command_name` string, with the real map data in the last ~2 MB.

**Why:** `record_test_map` in `bin/test` does `store_result(merge_results(RESULTSET, MAP_RESULTSET))` — the same shape as SimpleCov's own `merge_and_store`. SimpleCov's `create_result` labels a merged result by `distinct_names.uniq.sort.join(", ")` and `store_result` keys the resultset by that joined string. Feeding the stored composite back in as a source next run means generation N's label contains generation N-1's verbatim: ~500 bytes doubling per run, 4 GB after ~23 runs. `uniq` never helps — the giant joined string is one element that equals none of the 21 short worker names inside it. Stock SimpleCov escapes this only because `merge_timeout` (600 s) evicts the composite first; `record_test_map` passes `ignore_timeout: true` (correctly — the map is meant to be permanent), which removes that safety valve.

Symptom: `bin/test` parsing 4.5 GB of JSON took ~8.9 GB RSS beside 20 Rails workers on 31 GB RAM with swap exhausted, so the box thrashed and a run was OOM-killed (exit 137). `bin/rails test` stayed fine throughout because it never opens the map — that contrast is the fastest way to recognise this.

**How to apply:** the fix is in `bin/test`, pinning both fields the JSON formatter writes:

```ruby
MAP_COMMAND = 'test_map'
merged = SimpleCov::ResultMerger.merge_results(*sources, ignore_timeout: true)
merged.command_name = MAP_COMMAND
merged.command_names = [MAP_COMMAND]
SimpleCov::ResultMerger.store_result(merged)
```

Verified flat afterwards: three consecutive runs gave `command_name` length 8 and 842565 → 842625 → 842669 bytes. A healthy map is 839 KB–2.4 MB; check with `ls -lh coverage/map/coverage.json` and suspect this bug above ~10 MB. Recover by deleting the map and running a bare `bin/test` (only a no-argument run takes the `replace` path that clears `coverage/map/.resultset.json`).

Never drop the two `command_name` lines as "redundant" in a cleanup — a 2026-10-29 trim pass proposed it and a probe showed the resultset key turning into `"Minitest, test_map"` at once. Worktrees symlink main's `bin/test` since 2026-10-29 ([[project-local-helpers-manual-worktree-sync]]); related: [[project_worktree_coverage_seeding]].
