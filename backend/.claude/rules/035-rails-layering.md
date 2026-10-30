---
paths:
  - "app/**/*.rb"
---

# Rails Layering

## Controllers and models

- Model endpoints as CRUD on resources. When an action does not map to a CRUD verb, introduce a new
  resource instead of a custom action. JSON:API relationship endpoints use the `to_many` / `to_one`
  helpers in `config/routes.rb`.
- Thin controllers calling a rich domain model. Plain Active Record calls in a controller are fine;
  for anything more, expose an intention-revealing model method. No service layer.
- Controller helper methods stay private, even to satisfy reek: a public controller method counts as
  an action.
- Finding, loading and ordering domain data belongs on the domain class, also for POROs in `lib/`
  that read files instead of tables. A finder raises when nothing matches, like `.find`; an ordering
  gets a name (`newest_release_first`). No private controller helpers that glob, index or sort.
- No HTML in models or POROs. Escaping, `<code>` wrapping and `html_safe` belong in views, partials
  or helpers.
- Callbacks call a named private method, matching the existing style:
  `before_action(:set_docs_name)`, not a block. Leave out `only:` when the callback is cheap and
  harmless for every action.

<example type="invalid">

```ruby
def release
  file = changelog_files[params.fetch(:release)]
  raise(ActionController::RoutingError, 'Not Found') unless file

  @changelog = Changelog.new(file.read)
end

private

def changelog_files
  Rails.root.glob('openapi/changelog/*.json').index_by { it.basename('.json').to_s }
end
```

</example>

<example>

```ruby
def release
  @changelog = Changelog.find_release(params.fetch(:release))
end
```

</example>

## Model concerns live in `app/models/concerns/`

A new model concern always goes in `app/models/concerns/<model>/<name>.rb`. The constant stays
`<Model>::<Name>`, because `concerns/` is an autoload root. `app/models/<model>/` holds classes
only (`Organization::Group`, `Organization::SignupDomain`). Older concerns still sitting in
`app/models/user/` or `app/models/organization/` are no precedent; leave them unless asked to move them.

<example type="invalid">

```text
app/models/organization/signup_domains.rb   # module Organization::SignupDomains
```

</example>

<example>

```text
app/models/concerns/organization/signup_domains.rb   # module Organization::SignupDomains
```

</example>

## Async operations

Jobs are shallow and delegate to the domain model. Methods that enqueue a job take the `_later`
suffix (`notify_subscribers_later`, `generate_file_later`).

<example>

```ruby
class Inbox::MarkItemsAsReadJob < ApplicationJob
  def perform(membership, organization, marker_at)
    Current.set(organization: organization) { membership.mark_inbox_read(marker_at) }
  end
end
```

</example>
