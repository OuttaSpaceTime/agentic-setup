#!/usr/bin/env bash
set -euo pipefail
cd /home/felix/Code/Vilocify/vilocify-portal

for g in "bin/rails test:*" "bundle exec rubocop:*" "npx editorconfig-checker:*" \
         "bundle exec rake:*" "bin/openapi-diff" "bin/oasdiff" "bin/rails db:migrate:*"; do
  solve-allow add "$g" --file .claude/settings.json
done

mapfile -t locals < <(python3 -c "import json
d=json.load(open('.claude/settings.local.json'))
for p in d.get('permissions',{}).get('allow',[]):
    if p.startswith('Bash(') and p.endswith(')'): print(p[5:-1])")
for g in "${locals[@]}"; do
  solve-allow remove "$g" --file .claude/settings.local.json
done
