#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
bin/rails test \
  test/models/paginator_test.rb \
  test/models/paginator/json_api_cursor_test.rb \
  test/models/paginator/paginated_array_test.rb \
  test/lib/action_json_api/pagination_links_test.rb \
  test/integration/api/v2/inbox/items_controller_test.rb
echo "=== rubocop ==="
bundle exec rubocop app/models/paginator/json_api_cursor.rb test/models/paginator_test.rb
