---
name: dep-radar-tool
description: dep-radar — a local Next.js app at ~/Code/Misc/dep-radar that tracks direct-dependency releases for portal & frontend
metadata: 
  node_type: memory
  type: project
  originSessionId: 7036c149-1906-4720-ac69-b082dd65d120
---

`~/Code/Misc/dep-radar` is a Next.js 16 (App Router) + React 19 + TypeScript app (built 2026-06-23) that tracks **direct** dependency releases for `vilocify-portal` (gems + npm) and `vilocify-frontend` (npm), grouped by major/minor/patch, with per-release read/note/importance(Low–Critical) and filtering.

- Storage: SQLite via `better-sqlite3` at `data/dep-radar.db` (must be source-compiled for Node 24 — see README).
- Release notes are GitHub-first with a 3-tier fallback (Releases → CHANGELOG file → registry page); manual repo overrides in `lib/manual-repos.ts`.
- Boot sync (`instrumentation.ts`) reconciles against live lockfiles on `next dev` start; upgraded deps move to "applied history" (notes preserved). Throttled by `STALE_HOURS`. Needs `GITHUB_TOKEN` in `.env.local`.
- Tooling note: this environment's npm registry is time-pinned — see [[npm-registry-date-pinned]].
