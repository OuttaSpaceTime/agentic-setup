---
name: npm-registry-date-pinned
description: "The npm registry used by `npm install` in this environment is time-pinned (~2026-06-19); newer published versions fail to install"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 7036c149-1906-4720-ac69-b082dd65d120
---

`npm install` in this environment resolves against a **time-pinned npm registry** (cutoff around 2026-06-19). Packages published after that date fail with `ETARGET ... No matching version found ... with a date before <date>`.

`curl https://registry.npmjs.org/<pkg>` hits the LIVE registry (no cutoff), so the "latest" it reports may be newer than what `npm install` can actually fetch.

**How to apply:** When pinning deps, prefer caret ranges (e.g. `^8.0.0`) over exact latest-from-curl pins so npm resolves to the newest pre-cutoff version. If an exact pin fails with ETARGET, loosen it. Hit this with `typescript-eslint@8.62.0` (post-cutoff) while building [[dep-radar-tool]] — `^8.0.0` resolved to 8.61.1.
