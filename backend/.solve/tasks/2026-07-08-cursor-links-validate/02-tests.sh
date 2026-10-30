#!/usr/bin/env bash
set -euo pipefail
cd /home/felix/Code/Vilocify/vilocify-portal
bin/rails test test/integration/api/v2/inbox/items_controller_test.rb
