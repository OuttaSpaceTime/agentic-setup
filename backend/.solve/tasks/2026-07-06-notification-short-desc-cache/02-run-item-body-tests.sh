#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
bin/rails test test/models/monitoring_list/deleted_item_test.rb \
  test/models/monitoring_list/basic_data_updated_item_test.rb \
  test/models/monitoring_list/components_updated_item_test.rb \
  test/models/monitoring_list/component_eol_item_test.rb \
  test/models/monitoring_list/notification_item_test.rb \
  test/models/monitoring_list/dependencies_changed_item/removed_item_test.rb \
  test/models/monitoring_list/dependencies_changed_item/created_item_test.rb
