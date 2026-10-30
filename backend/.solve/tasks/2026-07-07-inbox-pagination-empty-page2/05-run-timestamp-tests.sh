#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
bin/rails test test/models/paginator_test.rb -i "/timestamp|whole second/"
