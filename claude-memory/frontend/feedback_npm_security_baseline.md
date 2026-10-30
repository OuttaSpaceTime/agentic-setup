---
name: feedback-npm-security-baseline
description: "Felix's npm/bun ignore-scripts and min-release-age settings are intentional org security policy, not misconfiguration — never loosen them to unblock a tool install"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 2df3394f-d09c-40f3-8ba3-4fe98a3160c8
---

Felix's `~/.npmrc` (and often project `.npmrc`) sets `ignore-scripts=true`, `min-release-age=4`, and `allow-git=none`. This matches the team's "Baseline npm security" knowledge card, which recommends these exact settings to reduce npm supply-chain attack exposure: scripts disabled by default, only packages older than 4 days installed, no transitive git dependencies, and `npx` avoided/hardened.

**Why:** Deliberate security baseline adopted org-wide, confirmed via the card the user shared — not something to "fix" or bypass when a tool's postinstall gets blocked.

**How to apply:** When a package's postinstall/lifecycle script is skipped (npm's `ignore-scripts` or Bun's default-secure trusted-dependencies list) and this breaks a CLI tool, do NOT recommend disabling `ignore-scripts` globally or adding the package to a blanket trust list. Instead: run the specific postinstall script manually for that one package (e.g. `cd node_modules/<pkg> && node postinstall.mjs`), or use a scoped/local install. Same logic applies to Bun's `trustedDependencies` — prefer a one-off manual fix over widening the trust list. If a tool has an autoupdate feature that silently reinstalls itself (e.g. opencode's `autoupdate` config, default `true`), that will re-trigger the same postinstall-skipped failure on every update — disabling autoupdate in the tool's own config is preferable to loosening the security settings.
