---
name: Single-line commits only
description: Claude may make small commits with one short single-line message and no trailer; never amend; rebases preserve commits unless Felix says otherwise
type: feedback
originSessionId: 3d89e25f-d27d-4ce3-9859-1a07d47e00d6
modified: 2026-10-28T08:14:52.808Z
---
Commits are allowed, and small ones are preferred, but every message must be a single line passed as one `-m` argument. No body, no bullet list, no trailer. Keep the subject short and plain.

**Why:** Felix's original rule was that I must never commit at all, after I committed reverts unasked. What actually bothered him turned out to be narrower: multi-paragraph messages with bullet bodies and a Co-Authored-By trailer, produced without him seeing them. He settled on "remove the attribution and allow only commits of a single line". On 2026-10-28 he added: agents should make small commits too, and a rebase must preserve the existing commits unless he says otherwise.

**How to apply:**
- Never `git commit --amend`. The zsh `git()` wrapper in `~/.zshrc` blocks it for Felix and reaches agents through the shell snapshot. That's intended, so don't work around it.
- A follow-up fix is a new small commit, not a fold into an earlier one.
- During a rebase, resolve conflicts inside the replayed commit (`git add` + `rebase --continue`). Never squash, fixup, reorder, drop or reword unless told. The `stack-rebaser` agent (`.claude/agents/` in the portal and frontend repos) follows this.
- Attribution is off at the source via `attribution.commit: ""` in the global settings; never add a trailer by hand.
- The old `single-line-commit.py` PreToolUse hook is gone (its last block was 2026-10-07), so the single-line rule is now on me.
- Show what gets committed and wait for Felix's OK before staging or committing. Hand off rather than commit when landing the change is his call.

See [[feedback_hooks_over_prompts]].
