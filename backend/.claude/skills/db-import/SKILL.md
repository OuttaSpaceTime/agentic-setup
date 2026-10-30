---
name: db-import
description: Import a PostgreSQL database dump from ~/Downloads into the vilocify-portal development database. Automatically selects the most recent .pgdump file. Requires Docker Compose running with postgres service. Use when you need to import a staging or production database dump.
---

# Import Database Dump

Note: This skill is also available as part of `/db-reset` with the "restore staging dump" parameter.

Import a PostgreSQL database dump from ~/Downloads into the development database.

## Prerequisites Check

Before starting, verify:
- Run `docker compose ps` to confirm postgres is running (needed for dump import)
- PostgreSQL client tools installed (`pg_restore`)
- Valid `.pgdump` file in `~/Downloads/`

If any prerequisite fails, report it to the developer before proceeding.

## Steps

### 1. Locate the dump file

- Search for `.pgdump` files in `~/Downloads/`
- If multiple files exist, select the most recent by modification time
- Display the selected file path and timestamp for confirmation

### 2. Convert pgdump to SQL format

```bash
cat /path/to/dump.pgdump | docker compose exec -T postgres pg_restore --format=c --no-owner --no-acl --clean -f - > dump.sql 2>&1
```

Notes:
- Use `-f -` (not `--file -`) to output to stdout
- `2>&1` captures warnings
- `--no-owner` and `--no-acl` avoid permission conflicts
- `--clean` drops existing objects before recreating

### 3. Import the SQL dump

```bash
cat dump.sql | bin/rails db -p
```

### 4. Clean up

- Ask before removing the temporary `dump.sql` file

## Error Handling

- If `docker compose ps` shows postgres is not running: run `docker compose up -d` and wait for it to be healthy
- If no .pgdump file found in ~/Downloads/: report to the developer and abort
- If pg_restore fails: verify the .pgdump file is not corrupted and is in custom format
- If SQL import fails on active connections: terminate them as in the db-reset skill's error handling (`pg_terminate_backend` against the dev DB name resolved from Rails) and retry

## Warnings

- Importing a dump **replaces existing data** in the development database
- Ensure Docker containers are running before starting
- The temporary `dump.sql` file can be large — ensure sufficient disk space
