---
paths:
  - "app/**/*.rb"
  - "openapi/**"
  - "test/integration/**"
---

# Request Validation Owns Input Consistency

## Requirements

- Whenever the OpenAPI spec can express a constraint on request input (`enum`, `pattern`, `required`,
  `minimum`/`maximum`, `minLength`/`maxLength`, `format`), declare it in `openapi/` and let request
  validation reject the request. Do not re-check the same constraint in a controller, model or job.
- Keep an application-level check only for what the spec cannot express: rules across several fields,
  or rules that depend on database state.
- An invalid body comes back as 422 with a `source.pointer` to the offending attribute; an invalid query
  parameter comes back as 400.
- Every new constraint gets an integration test that asserts the status **and** the full JSON:API error
  (`assert_jsonapi_errors`), so the test proves request validation rejected it, not application code.
  Mutation-verify it: drop the constraint from the spec, re-bundle, and confirm the test goes red.

<example>

```yaml
# openapi/paths/exports.yml — POST /exports params.sort
sort:
  type: string
  enum: [id, '-id', createdAt, '-createdAt', updatedAt, '-updatedAt', name, '-name']
```

</example>

<example type="invalid">

```ruby
# The spec accepts any string, and the export job raises later on an unknown key.
raise("Unknown column '#{sort_key}' for sorting") unless %w[id created_at updated_at name].include?(sort_key)
```

</example>
