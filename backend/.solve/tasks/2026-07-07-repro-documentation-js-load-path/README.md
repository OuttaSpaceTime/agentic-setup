# Reproduce: `documentation.js was not found in the load path`

Issue: after #1131, first test run fails on the documentation asset. Reproducible
with `rails assets:clobber`. Claim: precompile should not be necessary.

## Scripts

- `01-clobber-and-run-doc-test-as-ci.sh` — clobbers precompiled assets, then runs
  the documentation controller test. Result: PASSED (clobber removes the manifest,
  so propshaft uses the Dynamic load-path resolver). Did NOT reproduce.
- `02-precompile-then-run-doc-test.sh` — runs `assets:precompile` (creates
  `public/assets/.manifest.json`, flipping propshaft to the Static resolver), then
  runs the doc test. Verify: if the manifest omits `documentation.js`, the
  `sets correct CSP` test fails with "documentation.js was not found in the load path".
