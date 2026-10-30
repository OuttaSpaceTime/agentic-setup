# Diagnostic: dump EVERY SQL (with duration) fired by the real existing endpoint
# code path for Component sort=vendor (no btree) and Membership sort=user_name
# (btree), page 1. Then EXPLAIN ANALYZE the main ordered query. This tells us
# which query is the real sort and how long it truly takes. Rolled back.
#   bin/rails runner .solve/tasks/2026-07-20-incremental-sort-joined-order/06-diagnose-existing-sql.rb

def dump(label)
  seen = []
  sub = ActiveSupport::Notifications.subscribe('sql.active_record') do |_n, start, finish, _id, payload|
    next if payload[:name] == 'SCHEMA'
    seen << [((finish - start) * 1000.0).round(2), payload[:sql]]
  end
  yield
  puts("=== #{label} ===")
  seen.each { |ms, sql| puts("  #{ms.to_s.rjust(8)} ms  #{sql[0, 150]}") }
  puts
ensure
  ActiveSupport::Notifications.unsubscribe(sub)
end

Current.without_organization_and_membership_scopes do
  ActiveRecord::Base.transaction do
    seeder = DatabaseSeeder.new(
      organizations: 1, users: 30_000, memberships_per_user: 1..1,
      component_vendors: 4_000, component_names: 4_000, components: 20_000,
      notifications: 0, monitoring_list_per_org: 0, subscribers_per_ml: 0..0,
      components_per_ml: 0..0, inbox_items: 0, support_dropped_events: 0,
      ml_events_per_org: 0, notification_events_per_org: 0, admin_expiry_items_per_org: 0
    )
    seeder.run
    org = seeder.org_ids.first
    ActiveRecord::Base.connection.execute('ANALYZE users, memberships, components, component_vendors, component_names')

    dump('Component sort=vendor (page 1)') do
      Component.includable(fields: { 'components' => %w[vendor name] })
        .json_api_sort_and_paginate(sort: 'vendor', page: { size: 25 }).to_a
    end

    dump('Membership sort=user_name (page 1)') do
      Membership.unscoped.where(organization_id: org).includable
        .json_api_sort_and_paginate(sort: 'user_name', page: { size: 25 }).to_a
    end

    raise(ActiveRecord::Rollback)
  end
end
