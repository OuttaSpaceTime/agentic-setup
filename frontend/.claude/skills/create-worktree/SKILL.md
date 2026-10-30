---
name: create-worktree
description: >-
  Create one or more git worktrees of the vilocify-frontend repo that actually
  build and test, then verify `ng lint` and `ng test` pass in each. Use this
  whenever the user wants to spin up a worktree, set up a branch in a worktree,
  work on multiple issues/branches in parallel, or asks for a fresh checkout to
  run tests in — even if they don't say the word "worktree" (e.g. "give me a
  separate copy of the repo for branch X", "set up branches 591 and 592 so I can
  work on them side by side"). Handles the node_modules gotcha that makes a
  naive `git worktree add` fail to compile.
---

# Create Worktree

Spin up git worktrees of **vilocify-frontend** that compile and test like the
main repo, with lint + the full test suite verified green.

## When to use this

Trigger on requests like:

- "create a worktree for `591-...`" / "set up worktrees for these two branches"
- "I want to work on branch X and Y in parallel"
- "give me a fresh copy of the repo to run the tests in"
- any time the user needs an isolated checkout that must build/test

## The one gotcha that makes naive worktrees fail

`git worktree add` checks out tracked source only — it does **not** populate
gitignored files, so the new worktree has **no `node_modules/`**.

That matters more than usual here because a few imports are anchored to the
workspace root via `tsconfig` `baseUrl`, e.g.:

```ts
// src/app/features/api-tokens/components/api-token-card/api-token-card.component.ts
import { add } from 'node_modules/date-fns/add'
import { isPast } from 'node_modules/date-fns/isPast'
```

These only resolve when a `node_modules/` directory exists **at the worktree
root**. In a bare worktree `ng test` dies with `Could not resolve
"node_modules/date-fns/add"` even though `npx`/`ng` themselves run (those find
the binary by walking up the directory tree; baseUrl-anchored imports do not).

**Fix:** symlink the worktree's `node_modules` to the main repo's. Branches are
identical copies of the base, so the dependency tree matches and no 900 MB
reinstall is needed. The bundled script does this automatically.

## How to do it
Worktrees live in herdr's `<worktrees>/<repo>/<branch>` layout, sibling to the repo:
`../worktrees/vilocify-frontend/<branch-name>`, next to the backend's
`../worktrees/vilocify-portal/<branch-name>`. herdr (`[worktrees] directory`)
uses the same folder, so its sidebar and this script agree. Run the bundled
script with one or more branch names:
names:

```bash
bash .claude/skills/create-worktree/scripts/create-worktree.sh \
  591-ml-notification-inbox-item-page-renders-the-body-from-json \
  592-admin-summary-inbox-item-page-renders-the-body-from-json
```

The script, for each name:

1. Creates the worktree under `../worktrees/vilocify-frontend/<name>`, on
   a **new branch off `main`** named `<name>` (or
   attaches an existing branch of that name).
2. Symlinks `node_modules` to the main repo's (an **absolute** symlink, so it
   keeps working regardless of where the worktree lives).
3. Symlinks `.claude/` to the main repo's. `.claude/` is gitignored, so without
   this the worktree would have none of the project rules or
   `scripts/dev-server.sh` that the verification workflow depends on; a symlink
   (not a copy) means rule and settings changes reach every worktree at once.
4. Copies `.editorconfig-checker.json` (if present in the main repo) — same
   reason as `.claude/` above. It's locally gitignored (see `.git/info/exclude`
   in the main repo) since it excludes the generated `src/readme-oss.html`
   from the editorconfig check, a local convenience fix rather than a
   team-wide config change.
5. Runs `npx ng lint` then `npx ng test --watch=false
   --browsers=ChromeHeadlessNoSandbox` and stops on the first failure
   (`set -e`).

Useful env vars:

- `BASE=<ref>` — base the new branches off something other than `main`.
- `VERIFY=0` — create the worktrees but skip lint/tests (e.g. when you just want
  a checkout to start editing in).

`create-worktree.sh repair <worktree-path>` runs only steps 2–4 on an existing
worktree. herdr's `worktree.created` hook
(`~/Code/Vilocify/herdr-vilocify/bin/worktree_created.sh`) calls it for any new
worktree containing `angular.json`, so worktrees created from herdr are set up too.

The tests take a couple of minutes per worktree. When running them yourself
(rather than via this script), prefer launching with `run_in_background: true`
and run worktrees **sequentially** — Karma binds port 9876, so two suites at
once collide.

## What "success" looks like

- `ng lint`: `All files pass linting.`
- `ng test`: `TOTAL: <N> SUCCESS` (e.g. `921 SUCCESS`), exit code 0.

## Known caveats (don't treat these as failures)

- **`editorconfig-checker` reports ~180 errors** inside the generated OSS
  license file `src/readme-oss.html` if `.editorconfig-checker.json` wasn't
  copied (e.g. it didn't exist in the main repo yet when the worktree was
  created). The script deliberately does **not** run editorconfig-checker so
  it won't false-fail; mention the caveat if the user expected a fully clean
  `editorconfig-checker` and the file is missing.
- The `node_modules/date-fns/...` imports above are a pre-existing oddity, not
  something to "fix" as part of setting up a worktree. They work fine once the
  symlink is in place. Only touch them if the user explicitly asks.

## Cleaning up a worktree

```bash
git worktree remove ../worktrees/vilocify-frontend/<branch-name>   # add --force if dirty
git branch -D <branch-name>                         # if the branch is unwanted
```

`git worktree remove` handles the symlinked `node_modules` and the copied
`.claude/` fine. The worktree lives outside the repo tree, so nothing in it
(node_modules, `.claude/`) is ever part of a commit — the branch contains only
the base's tracked content.

> Moving an existing worktree: use `git worktree move <old> ../worktrees/vilocify-frontend/<name>`
> (it updates git's metadata). Remove the `node_modules` symlink first, then
> recreate it (`ln -s <main-repo>/node_modules <new>/node_modules`) since an
> absolute symlink is location-independent but the move won't recreate it.
