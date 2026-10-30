---
name: feedback_error_page_last_resort
description: "Error page (/500 redirect) is a last resort; prefer local, self-recovering error handling"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c43f55b2-400e-4f1e-9ba3-fdd487869fdd
---

The global `/500` redirect (via `redirectOnServerError` interceptor, see rule `210-http-error-handling`) should be the **last resort**. Whenever an error can be handled locally — inline error state, toast, retry, self-recovery — that is preferred over redirecting to the error page.

**Why:** A full-page error redirect destroys context and is a poor UX when only one request failed; local handling keeps the user in place and can self-recover.

**How to apply:** When reviewing/writing services, favor `CUSTOM_ERROR_HANDLING: true` + local `error:`/`catchError` handling (toast, inline state, retry) over letting the interceptor redirect. Rule `210` needs adapting to state this preference explicitly. See [[project_claude_rules.md]].
