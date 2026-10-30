# Fix missing icon on memberships status card

Bug (revised understanding): NOT an icon-name mismatch. `[name]="statusType"`
already resolves to a valid registered icon ('success'/'warning'/'error').
Confirmed live in the user's browser: after the bug triggers, `el.name` is
correctly `'success'`, but the icon never renders. This only reproduces via
SPA router navigation (switching sidebar items), never on a full page reload.

Working theory: a race between Angular's router-driven (lazy chunk, Promise-
based) creation of the `<ix-icon>` element and Stencil's own async lazy
component init — `loadIconContent()` (in `componentWillLoad`) reads
`this.name` before Angular's property binding actually lands, and the
`@Watch('name')` re-trigger that's supposed to self-heal doesn't visibly
recover the render.

Chrome extension (claude-in-chrome) is not connecting, so using Playwright via
`bun` (cached Chromium already available) as a CLI alternative to reproduce
and instrument this live.

## 01-check-playwright.sh

Sanity-checks that `bunx playwright --version` works without needing to
download anything, before writing the actual repro script.

Verify: run the script, expect a version string, no download prompts.
