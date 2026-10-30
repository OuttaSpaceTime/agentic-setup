---
name: feedback-no-pass-through-collaborators
description: A class must not hold a collaborator purely to hand it back to another class; derive it where it is owned
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 2ab54d45-9ab9-4fdc-8bd7-07c35b79cba6
  modified: 2026-09-21T10:35:44.241Z
---

Felix rejects a design where class A takes a collaborator in its constructor only so class B can
read it back off A. He spotted it unprompted in `Keyset::Page#initialize` doing
`@columns = page_params.columns`, where `Pagination::Params` held `Keyset::Columns` solely to expose
it again — "why do the params need to know about the columns now? this feels wrong."

**Why:** the keyset is a property of the *scope*, and `Keyset::Page` already owns the scope, so it
can call `Keyset::Columns.of(scope)` itself. `Pagination::Params` should read only `page[size]` and
`page[after]`. A pass-through `attr_reader` is the tell that a responsibility landed in the wrong
class.

**How to apply:** when a value is reachable from something a class already holds, derive it there
instead of threading it through a constructor. If the only thing forcing the coupling is that the
ActiveModel doing `validate!` needs the collaborator to validate one field, move that failure out
of validation entirely — raise a dedicated error and register it in
`ActionJsonApi::ErrorResponses.definitions` (status + title + `source: { 'parameter' => … }`), which
renders the identical 422 body. Precedent in that registry:
`JSONAPI::Serializer::UnsupportedIncludeError`. Cost is one registry entry plus one line in
`errors_controller_test.rb`'s `KIND_STATUSES`; the kind slug comes from `name.demodulize.underscore`,
so name the error so that slug reads well — propose candidates first, see
[[feedback-suggest-names-in-chat]].

Trade-off to state up front: `validate!` now short-circuits, so a request with both a bad page key
and a bad cursor reports only the first error instead of accumulating both.

Related: [[feedback-unnecessary-safety-returns]], [[project-keyset-cursor-trust-model]]
