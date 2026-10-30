---
paths:
  - "**/*.rb"
---

# Ruby Code Style

## Context

- Applies to all Ruby: `app/`, `lib/`, `test/`, `config/`.
- `bin/rubocop -A` is the arbiter of formatting. This file covers what RuboCop cannot check.
- When writing new code, find similar code elsewhere in the codebase first and follow it.

## Requirements

### Favor Rails-native modelling

Reach for the framework API before hand-rolling. Prefer:

- `validates` / a validation method over checks scattered through callbacks.
- `dependent: :destroy` / `:nullify` on the association over a manual cleanup callback.
- `belongs_to …, optional: true` plus `&.` over branching on a missing parent.
- `where` / `order` / scopes over filtering and `sort_by` in Ruby.
- `find_or_create_by`, `insert_all` over read-then-write branches.
- `presence`, `Array.wrap`, `in_groups_of` over hand-written nil and empty handling.
- A gem already in the `Gemfile` over a hand-rolled parser or regex renderer (`redcarpet` for
  Markdown, `JSON.parse` for data). The maintainer rejects custom parsers.

### Guard clauses

Guard clauses are preferred over nesting: one condition per line, followed by a blank line. They
belong in the method's preamble — before the main work starts — which may sit after the local
assignments the condition needs. Once the real work has begun, express branching as `if`/`else`
rather than threading `return`s through the body.

<example>

```ruby
def deliver(event)
  return if event.processed_at?

  Current.set(organization: event.organization) do
    event.with_lock { … }
  end
end
```

</example>

### Readable control flow over hidden state

Write a flow a reader can follow top to bottom in one method: explicit `if`/`else`, a `fail!`/`raise`
where the failure happens, values passed in as arguments and returned. Hidden state makes the reader
rebuild the order of events from other places: instance variables set in one method and read in
another, callbacks that run out of sight, exceptions rescued far from where they're raised. Add
these only when they bring something the plain flow can't:

- **A new class** when it gives a multi-step flow one named entry point (e.g. moving it out of a
  controller), not to wrap a single method.
- **Callbacks** when a step must run for every save or action whatever the caller, not to sequence
  one flow.
- **Active Model validations** when the errors reach a client or the record is validated from
  several places. A one-off precondition is an `if` plus `fail!`.
- **Memoization** (`@x ||=`) when the same object reads an expensive value several times, not to
  pass state between the methods of a one-shot call.

<example type="invalid">

```ruby
def callback
  authentication = Auth0::Authentication.from_request_env(request.env)
  authentication.validate!
  user = User.authenticate_with_oauth!(authentication)
  # ...
rescue ActiveModel::ValidationError
  redirect_to_login!(message_code: :generic_error)
rescue ActiveRecord::RecordNotFound
  if User.email_conflict?(authentication)
    redirect_to_login!(message_code: :email_conflict)
  else
    redirect_to_login!(message_code: :user_not_found)
  end
end
```

</example>

<example>

```ruby
# User::Login (branch 1192-extract-user-login); the controller rescues only LoginFailure
def authenticate(request_env)
  authentication = validate_auth0_payload!(request_env)
  user = User.find_with_authentication(authentication)

  if user
    user.update!(authentication.slice(:name, :avatar_url, :siemens_gid, :siemens_auth0_id))
    Result.new(user.id, authentication.provider)
  else
    fail!(conflict_or_not_found(authentication))
  end
end
```

</example>

### Method ordering

1. `class` methods
2. `public` methods, `initialize` first
3. `private` methods

Order methods vertically by invocation order, so a method appears above the ones it calls.

### Bang methods

`!` marks a method that raises on failure or performs a destructive/privileged action
(`add_components!`, `authorize!`, `insert_all_revisions!`). A non-bang counterpart is not required.
