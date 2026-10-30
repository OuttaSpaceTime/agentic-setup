---
name: project-siemens-llm-gateway
description: Siemens LLM gateway /models list is unreliable both ways; opencode.json is the authoritative model list
metadata: 
  node_type: memory
  type: project
  originSessionId: fb8b5ba5-7fcf-44da-b1cf-7768abeb82fb
  modified: 2026-09-18T07:13:12.749Z
---

The Siemens LLM gateway (`https://api.siemens.com/llm/v1`, OpenAI-compatible) has a
`/models` endpoint that is **not** a faithful inventory, verified 2026-09-18:

- **Listed but not callable**: `claude-opus-5`, `claude-opus-4-8`, `gpt-5.6-terra`, `glm-5.2`
  all return `404 No matching route found ... not configured in the Gateway`. A *bad key*
  gives `403 You cannot consume this service`, so 404 = authenticated but unprovisioned.
- **Callable but not listed**: `qwen-3.6-27b` (the portal default) and the four older models
  in the global opencode config are absent from `/models` yet work.

Authoritative model list is the repo's `opencode.json`, not discovery:
`qwen-3.6-27b` (default), `ministral-3-14b-instruct-2512` (small_model),
`qwen-3.8-27b`, `deepseek-v4-flash`.

Model metadata from any agent's bundled catalog is also wrong here — it matches by model id
and falls back to a generic `128K context / 33K max-out` (that default was applied even to
`whisper-large-v3-turbo` and the embedding/reranker models). Real limits live in `opencode.json`.

**Why:** trusting the gateway's model list or a catalog's limits leads to picking dead routes
and to compacting context 4x earlier than necessary.

**How to apply:** when configuring a new agent against this gateway, copy the model set and
limits from `opencode.json` and pin them explicitly; treat discovery as additive only, and
probe any new model with a one-token call before relying on it. See [[project-omp-setup]].
