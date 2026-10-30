# `destroy_all` vs `each(&:destroy)` vs `delete_all` in Rails

Rails offers three ways to remove records in bulk. They differ in whether they
instantiate records, fire callbacks (including `dependent:` associations), and
how they manage relation state afterward.

## TL;DR

- `destroy_all` and `each(&:destroy)` are nearly identical — both load all records
  into memory, call `destroy` on each (firing all callbacks), and differ only in that
  `destroy_all` resets the relation cache via `tap { reset }`.
- `delete_all` issues a single bulk `DELETE` SQL statement. No records are instantiated,
  no callbacks fire, no `dependent:` associations are cleaned up.

## `destroy_all` internals

```ruby
# ActiveRecord::Relation
def destroy_all
  records.each(&:destroy).tap { reset }
end
```

- `records` evaluates SQL, caches result
- `.each(&:destroy)` iterates the cached Array, returns it
- `.tap { reset }` calls `Relation#reset`, clears `@records` and `@loaded`, returns the Array unchanged

Both methods snapshot upfront (both call `records` first).

## Cache difference after completion

```ruby
relation = Post.where(archived: true)

relation.destroy_all
relation.loaded?  # => false  (reset clears cache)

relation.each(&:destroy)
relation.loaded?  # => true   (stale destroyed objects remain cached)
```

Irrelevant when the scope is called fresh each time (cleanup jobs), matters if reusing the relation variable:

```ruby
relation = Post.where(archived: true)

# destroy_all resets — second access re-queries the database
relation.destroy_all
relation.count           # SQL query → 0 (records are gone)
relation.to_a            # SQL query → []

# each(&:destroy) does not reset — second access returns stale cache
relation = Post.where(archived: true)
relation.each(&:destroy)
relation.count           # SQL query → 0 (count always queries)
relation.to_a            # NO query — returns stale Array of frozen, destroyed objects
relation.reset.to_a      # SQL query → [] (manual reset forces re-query)
```

Note: `count` always hits the database regardless of cache state. Methods that
use `records` internally (`to_a`, `each`, `map`, `first` on a loaded relation)
return the stale cache.

## `destroy` vs `delete`

`dependent:` options are registered as `before_destroy` callbacks. They only fire through `destroy`, never through `delete`:

```ruby
class Post < ApplicationRecord
  has_many :comments, dependent: :destroy  # before_destroy callback
end

post.destroy     # deletes post AND all comments (callback fires)
post.delete      # comments orphaned
Post.delete_all  # all children of posts orphaned
```
