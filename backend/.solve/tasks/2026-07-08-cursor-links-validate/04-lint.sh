#!/usr/bin/env bash
set -euo pipefail
cd /home/felix/Code/Vilocify/vilocify-portal
bundle exec rake action_json_api:lint
