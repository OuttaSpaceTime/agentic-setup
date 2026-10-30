---
paths:
  - "src/**"
---

# Code Verification

**These steps are mandatory. Changes are not complete until every applicable check passes.**

Run after modifying TypeScript, HTML, or CSS files.

## Dev Server Lifecycle

Start the dev server at the **beginning** of every task — do not wait until after edits:

```bash
bash .claude/scripts/dev-server.sh
```

This either starts a new server or confirms an existing one is running. Note the PORT and LOG path from the output.

**Keep the server running throughout the task.** Angular recompiles incrementally on each file save, giving continuous compilation feedback.

To check compilation status after edits:

```bash
tail -30 /tmp/claude-ng-serve-vilocify-frontend.log
```

Look for `compiled successfully` or compilation errors in the output.

If the dev server crashed, restart it with `bash .claude/scripts/dev-server.sh`.

If `dev-server.sh` reports **"No free port found"**, the port range (4201–4210) is exhausted by orphaned servers from other worktrees/sessions. Reap them all with:

```bash
bash .claude/scripts/dev-server-kill-all.sh
```

This kills every `ng serve` process for the project (not just the tracked one) and frees the range. Then re-run `dev-server.sh`.

At the **end of all tasks**, stop the server:

```bash
bash .claude/scripts/dev-server-stop.sh
```

## Look at UI changes

Tests and a clean compile don't show layout. After changing a template or styles, open the page on
the dev server's port with headless Chrome in its own profile and read the screenshot:

```bash
google-chrome --headless=new --disable-gpu --no-first-run --user-data-dir=<scratchpad>/chrome-profile --hide-scrollbars --window-size=1280,900 --screenshot=<scratchpad>/page.png http://localhost:<PORT>/<path>
```

If the page needs a login you can't script, say the visual result is unverified and give the user
the URL to check.

The `gate-runner` agent (`.claude/agents/`) runs the steps below with full output and returns the
failures; delegate to it instead of skipping a step.

## Steps (in order)

```bash
npx ng lint --fix
```

Then verify compilation by checking the dev server log:

```bash
tail -30 /tmp/claude-ng-serve-vilocify-frontend.log
```

## Running Tests

**Always run the tests for every spec file that covers changed code.** If there is no spec file for a changed file, say so explicitly. Do not skip this step.

Target only affected spec files:

```bash
# Changed files
SPECS=$(git --no-pager diff --name-only | grep '\.spec\.ts$')
for spec in $SPECS; do
  npx ng test --include="$spec" --watch=false --browsers=ChromeHeadlessNoSandbox
done

# By directory
npx ng test --include='src/app/features/dashboard/**/*.spec.ts' --watch=false --browsers=ChromeHeadlessNoSandbox

# Multiple files
npx ng test \
  --include='src/app/core/interceptors/foo.interceptor.spec.ts' \
  --include='src/app/features/bar/bar.component.spec.ts' \
  --watch=false --browsers=ChromeHeadlessNoSandbox
```

## When to Run strict-migrate.mjs

Run `node strict-migrate.mjs` whenever the change touches: TypeScript types, tests, fixtures, factories, auth/session models, or permission code.

- If strict errors **decreased**: update `CURRENT_ERRORS` in `strict-migrate.mjs` in the same change
- If strict errors **increased**: fix the types — never raise the budget

## When to Run the Full Test Suite

Run `npx ng test --watch=false --browsers=ChromeHeadlessNoSandbox` when:
- Change is in `src/app/shared/`, auth, routing, or permission logic
- User asks for merge readiness

For isolated component/template/style changes, targeted spec files are sufficient.

<critical>

  - **Start the dev server at the beginning of every task** with `bash .claude/scripts/dev-server.sh`
  - **Each task must be validated before moving to the next**: run lint, check the dev server log for compilation status, and run the targeted spec files that cover the changed code
  - **After all tasks are complete**, run the full test suite (`npx ng test --watch=false --browsers=ChromeHeadlessNoSandbox`) to catch cross-cutting regressions
  - **Stop the dev server at the end** with `bash .claude/scripts/dev-server-stop.sh`
  - **Each check must pass with zero errors before handing back to the user.** If any check fails: read the full error output, fix the issue, and re-run that check. Repeat until it passes. Do not skip or defer failing checks.
  - A change is NOT complete until the dev server log confirms successful compilation — a clean lint is not enough
  - Fix compilation errors before running tests — Angular compiles the entire app even with --include
  - Tests must pass before declaring work done — do not hand back to the user with failing tests
  - Never filter test output with grep, awk, tail, or head

</critical>
