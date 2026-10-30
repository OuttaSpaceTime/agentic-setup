---
name: db-reset
description: Complete database reset for the vilocify-portal Rails backend. Checks out the base branch (main, or the parent branch when stacked), drops and recreates the database, loads data there (fixtures by default, or staging dump with parameter), then switches back to your branch and migrates — so your branch's migrations run against real pre-migration data. Use when you need a clean local development database, or before inspecting a data migration's before/after effect.
---

# Database Clean Reset

Performs a complete database reset for the vilocify-portal development environment.

## Parameters

- **Optional**: Pass "restore staging dump" to import a database dump from ~/Downloads instead of loading fixtures.
- **Optional**: Pass a base ref (`base <branch>`). Defaults to `main`.

## Prerequisites Check

- `git status --porcelain` must be clean enough that `git checkout <base>` succeeds. If it is not,
  report the dirty files and stop — never stash or commit on the developer's behalf.
- For a dump import: `docker compose ps` shows postgres running.

## Steps

Data is loaded **on the base's schema, before this branch's migrations run**. That order is the
whole point: `db:migrate` then has real pre-migration rows to actually transform, which is what
makes a manual before/after inspection possible (see the **script-migrate** skill).

### 0. Pick the base ref

With stacked branches the base is the parent branch, not `main` — resetting to `main` would replay
the parent's migrations too and hide what *this* branch does. Show the developer what sits between
the candidate base and `HEAD` and let them confirm:

```bash
git log --oneline main..HEAD
```

If those commits include work from a branch below this one, use that branch as `<base>` instead.

`~/Code/Vilocify/.bin/vil-db-reset [<base>] [--branch-fixtures]` does all of this, including the
guards below. Prefer it; run the steps by hand only when it refuses and you need to see why.

### 1. Load the base's schema and data

```bash
git checkout <base>
bin/rails db:drop db:create db:schema:load db:fixtures:load
```

**If "restore staging dump" was requested**, replace `db:fixtures:load` with the dump import while
still on the base: locate the newest `.pgdump` in `~/Downloads/`, then

```bash
cat ~/Downloads/<dump>.pgdump | docker compose exec -T postgres pg_restore --format=c --no-owner --no-acl --clean -f - > dump.sql 2>&1
```

```bash
cat dump.sql | bin/rails db -p
```

and delete `dump.sql` afterwards.

### 2. Switch back and migrate

When checking a migration, stop after `git checkout -` and take the before snapshot first
(Readme.md "Manual testing", step 2); the script-migrate skill has the queries.

```bash
git checkout -
bin/rails db:migrate
```

`db:migrate` rewrites `db/schema.rb` — expected, leave it.

## Error Handling

- If `db:schema:load` fails on the base: the base branch itself is broken — `git fetch origin` and check the base is up to date
- If `git checkout -` lands somewhere unexpected (detached HEAD, wrong branch): check out the branch by name instead
- If db:drop fails due to active connections: terminate them first. Worktrees use isolated database names (see the create-worktree skill), so resolve this checkout's dev DB name from Rails rather than hardcoding it:
  ```bash
  dev_db="$(bin/rails runner -e development 'print ActiveRecord::Base.connection_db_config.database')"
  docker exec vilocifyportal-postgres-1 psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${dev_db}' AND pid <> pg_backend_pid();"
  ```
- If dump import fails: verify Docker Compose is running and .pgdump file exists in ~/Downloads/
- If migrations fail: this usually means data from the dump conflicts with new migrations — report the error

## Warnings

- This command **destroys all local database data**
- The base branch must be checkout-able and its schema.rb in a good state
- You end up back on your branch with `db/schema.rb` rewritten by `db:migrate`
- For dump import: Docker Compose must be running with postgres service
