# Trace the fan-out case: filter by TWO notifications where one component carries both.
# Prints every intermediate row set so each count is derivable by hand. Read-only.
#   RAILS_ENV=test bin/rails runner .solve/scripts/trace-fanout-two-notifications.rb

def fixture_id(label, type = nil) = ActiveRecord::FixtureSet.identify(label, type)

membership = Current.without_organization_and_membership_scopes do
  Membership.unscoped.find(fixture_id(:ml_observer_as_user_in_a, :uuid))
end

Current.set_from_membership(membership) do
  privilege_escalation = Notification.find(fixture_id(:privilege_escalation))
  eol_notification = Notification.find(fixture_id(:eol_notification))
  filtered = [privilege_escalation, eol_notification]
  filtered_ids = filtered.map(&:id)

  puts("membership: ml_observer_as_user_in_a")
  puts("filtered notifications: #{filtered.map { |n| "#{n.id} (#{n.title.to_s[0, 30]})" }.join(', ')}")

  puts("\n1. MLs this membership can see (MonitoringList.visible):")
  MonitoringList.visible.order(:name).each do |ml|
    puts("   #{ml.name.to_s.ljust(16)} components=#{ml.visible_components.map(&:id).inspect}")
  end

  puts("\n2. every (ML, component, filtered-notification) row the JOIN produces:")
  join_rows = MonitoringList.visible
    .joins(visible_components: :notification_component_assignments)
    .where(notification_component_assignments: { notification_id: filtered_ids })
    .pluck(
      'monitoring_lists.name',
      'components.id',
      'notification_component_assignments.notification_id'
    )
  join_rows.sort.each { |ml, component, notification| puts("   #{ml.ljust(16)} component=#{component} notification=#{notification}") }
  puts("   -> #{join_rows.size} join rows")

  puts("\n3. MLs matched (what the filter should select):")
  matched = MonitoringList.visible.by_notifications(filtered_ids).order(:name)
  puts("   #{matched.map(&:name).inspect}")

  puts("\n4. the numbers:")
  all_pairs = matched.sum { |ml| ml.visible_components.size }
  puts("   TRUTH  all (ML, component) pairs of matched MLs ......... #{all_pairs}")
  puts("   join rows without DISTINCT (ML, component, notification)  #{join_rows.size}")
  puts("   join rows with DISTINCT -> COUNT(DISTINCT ml.id) ........ #{matched.size}")
  puts("   distinct (ML, component) pairs inside the join .......... #{join_rows.map { |r| r[0, 2] }.uniq.size}")
end
