# ML relationships/components + fields/include

1. Mint a bearer token for superuser_as_admin_in_a.
2. Pick the first monitoring list in org A that has components.
3. GET /api/v2/monitoringLists/:id/relationships/components with
   a) fields[components]=createdAt
   b) include=components
   c) include=components&fields[components]=createdAt
   d) include=components&fields[components]=createdAt,name
4. Print status, exception and body for each.

## request_variants.rb
Same flow, variants: snake_case field value, singular/typo fields type, singular include.

## request_user_ml.rb
The user's exact query on ML fd836bbb-…, then the same query plus include=components.

## ml_component_counts.rb
Count components on ML fd836bbb-… without scopes, then as superuser_as_admin_in_a (components vs visible_components).
