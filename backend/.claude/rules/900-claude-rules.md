---
paths:
  - ".claude/**"
  - "CLAUDE.md"
  - "AGENTS.md"
---

# Writing Claude Rules, Skills and Agents

## Context

- `.claude/` and `CLAUDE.md` are local-only (`.git/info/exclude`) and symlinked into every worktree.
  Edit them in the main checkout; a change reaches all worktrees at once. Nothing here has git
  history, so copy a file aside before restructuring it.
- `AGENTS.md` is tracked and owned by the team. Don't edit it unless asked; it changes through an MR.

## Requirements

### Format

- Frontmatter holds only `paths:` with quoted globs. Leave it out only for a rule every session
  needs, and keep those few.
- One topic per file, under ~200 lines. Split by topic into the next free number: `0XX` code,
  `3XX` tests, `8XX` workflows, `9XX` meta.
- `# Title`, then `## Context` (when it applies) and `## Requirements`, where they help.
- Examples go in `<example>` and `<example type="invalid">` blocks, one case per block, with a
  one-line comment saying why. No ✅/❌ pairs inside a single code block.
- Leave a blank line after every opening `<example>`/`<critical>` tag and before its closing tag,
  and put code in a fence with its language (```ruby). Otherwise editors render the code as
  Markdown and show the tags as unpaired.
- `<critical>` at most once per file, for true absolutes.
- A new rule file gets a line in the "Key Rules" list of `CLAUDE.md`.

### Content

- State the project-specific rule and a short reason. Leave out what Claude or Rails already do,
  what RuboCop enforces, and what the global `~/.claude/CLAUDE.md` says.
- Every example must work on `main` today: check that the helpers, fixture labels, methods and
  permission strings exist, and probe a framework claim before writing it down. A stale example
  teaches the agent broken code.
- Name code by class, method or file, never by line number.
- Link another rule by file name instead of repeating it.
- Write instructions, not history: no "since …", ticket numbers or who asked.
- Commands match what `.claude/settings.json` allows and use the repo's `bin/*` wrappers.
- A rule that can be checked mechanically (creating a file, a banned string) is better as a hook in
  `.claude/hooks/`, registered in `.claude/settings.json`.

### Skills and agents

- Skills live in `.claude/skills/<name>/SKILL.md`, agents in `.claude/agents/<name>.md` with
  `name`, `description`, `tools` and `model` frontmatter. The description decides when they are
  used: say what it does and when.
- `stack-rebaser` and `gate-runner` exist in this repo and in vilocify-frontend; change both copies
  together.

### After editing

- Check that the `paths:` globs match the files the rule is meant for.
- Search the other rules, skills, hooks and memories for references to anything you renamed or moved.
