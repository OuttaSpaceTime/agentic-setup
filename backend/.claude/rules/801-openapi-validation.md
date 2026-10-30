---
paths:
  - "openapi/**"
  - "redocly.yaml"
  - "public/openapi/**"
---

# Validate OpenAPI Docs

## Requirements

After generating or modifying OpenAPI documentation files:

1. `bin/openapi-diff` — check bundled specs are current
2. `bin/oasdiff` — detect breaking API changes vs `origin/main`
3. `bin/redocly-lint` — validate OpenAPI structure

Include the outcome of every command in the response.

<example>

Modified OpenAPI component, ran all three validation commands, reported results.

</example>

<example type="invalid">

Updated openapi/components/MyComponent.yml without running validation commands.

</example>
