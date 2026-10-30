# Is the CLAIM true — that the existing endpoints (old Paginator cursor path) are
# slow for all 4 joined sorts? Runs the REAL json_api_sort_and_paginate on each
# controller's actual scope, page 1 and a cursor page, and records the real DB
# time of the ordered/keyset SELECT (min of 5 runs). Rolled back.
#   bin/rails runner .solve/tasks/2026-07-20-incremental-sort-joined-order/05-existing-endpoints-joined-sort.rb

def measure(label)
  durations = []
  sub = ActiveSupport::Notifications.subscribe('sql.active_record') do |_n, start, finish, _id, payload|
    next if payload[:name] == 'SCHEMA' || payload[:sql] !~ /ORDER BY/i
    durations << ((finish - start) * 1000.0)
  end
  result = nil
  5.times { result = yield }
  puts("  #{label}: #{durations.min&.round(2)} ms  (min of #{durations.size} ORDER BY queries)")
  result
ensure
  ActiveSupport::Notifications.unsubscribe(sub)
end

def next_cursor(page) = page.links.dig(:next, :page, :after)

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

    fields = { fields: { 'components' => %w[vendor name] } }
    comp   = -> { Component.includable(fields) }
    mem    = -> { Membership.unscoped.where(organization_id: org).includable }

    cases = {
      'Component  sort=vendor'     => [comp, 'vendor'],
      'Component  sort=name'       => [comp, 'name'],
      'Membership sort=user_name'  => [mem,  'user_name'],
      'Membership sort=user_email' => [mem,  'user_email']
    }

    puts("components=#{Component.count}  memberships(org)=#{Membership.unscoped.where(organization_id: org).count}\n\n")

    cases.each do |label, (scope, sort)|
      puts("=== #{label} ===")
      page1 = measure('page 1     ') { scope.call.json_api_sort_and_paginate(sort: sort, page: { size: 25 }) }
      cursor = next_cursor(page1)
      measure('cursor page') { scope.call.json_api_sort_and_paginate(sort: sort, page: { after: cursor, size: 25 }) }
      puts
    end

    raise(ActiveRecord::Rollback)
  end
end
