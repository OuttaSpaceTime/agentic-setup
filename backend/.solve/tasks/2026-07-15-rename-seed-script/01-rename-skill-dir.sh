#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
mv .claude/skills/seed-script .claude/skills/script-seed
ls .claude/skills/
