#!/usr/bin/env bash
set -uo pipefail
cd /home/felix/Code/Vilocify/vilocify-portal
bin/rails assets:clobber
bin/rails test test/integration/documentation_controller_test.rb
echo "exit: $?"
