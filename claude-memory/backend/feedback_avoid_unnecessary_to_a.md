---
name: feedback_avoid_unnecessary_to_a
description: Never call .to_a when the object is already Enumerable and the next method accepts any Enumerable
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 878550f3-9c1e-4e67-8b0d-a33c538e896b
---

Never call `.to_a` on an ActiveRecord scope/relation. Ever.

**Why:** It forces eager loading of the entire result set into memory, bypassing lazy evaluation, batching, and query optimisation. Felix is emphatic about this — it's a hard rule, not a style preference.

**How to apply:** If you see `.to_a` on anything that is or could be an ActiveRecord relation, remove it. Use `.load` only if materialisation is genuinely needed (e.g. repeated iteration), but even then, question whether the design can avoid it. `.to_a` on `ActiveRecord::Result` (e.g. after `.insert_all`) is fine — that is already an in-memory object, not a scope.
