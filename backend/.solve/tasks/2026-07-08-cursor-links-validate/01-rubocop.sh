#!/usr/bin/env bash
set -euo pipefail
cd /home/felix/Code/Vilocify/vilocify-portal
bundle exec rubocop -A app/controllers/concerns/api_serialization.rb
