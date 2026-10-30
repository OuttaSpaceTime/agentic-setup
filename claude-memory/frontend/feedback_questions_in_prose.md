---
name: feedback-questions-in-prose
description: Ask design and decision questions in plain chat after explaining the problem; the AskUserQuestion dialog only for permission prompts
metadata:
  node_type: memory
  type: feedback
  originSessionId: 494207d6-2a06-471a-81c3-df02836ad80c
  modified: 2026-10-28T08:31:26.888Z
---

Ask design and decision questions in chat, after explaining the problem in plain words. Don't use the AskUserQuestion dialog for them.

**Why:** In the transcripts from 2026-09-29 to 2026-10-28, Felix rejected 18 of 138 AskUserQuestion dialogs. He usually followed with a prose question like "i do not understand the issue" or "i need to understand how the tests behave". The dialog hides the explanation he needs before he can decide.

**How to apply:**
- Explain the situation first, then ask one plain question.
- Offering 2–3 options with tradeoffs is still right (`feedback_present_options`). Write them in the chat, not in a dialog.
- Keep the dialog for permission questions the org rules require as multiple choice (push, remote infrastructure, new dependencies).

Related: [[feedback_present_options]].
