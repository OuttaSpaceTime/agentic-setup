---
paths:
  - "src/app/shared/jsonapi/**/*.ts"
---

# JSON:API Resource Types

## Context

Applies to resource type definitions in `src/app/shared/jsonapi/resources.ts`.

## Requirements

- Define a resource as a single `export type X = JsonApiResource<{ ...inline attributes... }>`. Inline the attribute object literal directly into the generic.
- Do NOT declare a separate `interface XAttributes` and then `interface X extends XAttributes`. That indirection is not the file convention.
- A shared base object reused across several resources (e.g. `InboxItemBase`) may be a named type and intersected in via `&` — that is fine.
- Flattened (non-`JsonApiResource`) shapes, e.g. an entry with `id`/`type` but no `attributes` wrapper, stay plain `interface`s — this rule is only about resource types.

<example>

```ts
export type IApiToken = JsonApiResource<{
  name: string
  createdAt: string
  expiresOn: string
  description: string
}>
```
Attributes inlined into the generic — matches every other definition in the file.

</example>

<example type="invalid">

```ts
interface InboxNotificationEntryAttributes {
  deleted: boolean
  title?: string
}
export interface IInboxNotificationEntry
  extends InboxNotificationEntryAttributes {
  id: string
  type: 'inboxNotificationEntries'
}
```
Splits attributes into a separate interface and extends it. Inline the literal instead.

</example>
