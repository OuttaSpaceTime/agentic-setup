---
name: project-aweseno-v2-param-stays
description: The version=v2 param on Aweseno sync requests must stay on the wire; only the Rails config flag was removed
metadata: 
  node_type: memory
  type: project
  originSessionId: 83d1f821-5b2f-4e80-bee1-c51c4bcaf928
  modified: 2026-10-27T20:09:16.635Z
---

Work item 1211 ("Remove v2 sync", 2026-09-01) removed only the Rails flag
`config.enable_sync_version_2`. `Aweseno::Api.sync_params` still sends
`version: 'v2'` unconditionally.

**Why:** Karim ElGhandour, asked directly whether the query param could go too:
"No. Do not remove the query param" — dropping it "would require an SVM change",
because Aweseno does not default to v2 server-side. Removing it would silently
regress restricted-record sync (`restricted` on notifications, `siemens_internal`
on components are v2-only fields feeding `tlp_amber_strict`).

Asked whether to file a follow-up: "not immediately tbh. I don't care enough
about this. Maybe with pagination and so on we will revisit all of the sync."
So there is deliberately **no** follow-up issue — the param comes up again only
if/when sync gets reworked for pagination.

Because the param stays, Felix also kept the **v1 fixture dumps**: `__aweseno__/`
still holds both the v1 payloads at top level and the v2 payloads in
`__aweseno__/v2/`, and `FakeAwesenoController#read_fixture` keeps its
`params[:version] == 'v2'` directory branch. Tests reference the v2 set as
`aweseno_fixture('v2/...')`.

**How to apply:** Do not "clean up" the hardcoded `version: 'v2'` in
`lib/aweseno/api.rb#sync_params`, the v1 dumps, or the controller's version
branch. All three are intentional, not leftover — even though the app itself now
only ever requests v2, so the v1 path is reachable only by hand. The v2 payloads feed the restricted-record feature
(`TlpAmberStrict`).
