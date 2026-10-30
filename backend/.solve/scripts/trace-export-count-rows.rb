# Trace exactly which rows produce 5 / 4 / 6 for components_count, by listing the
# (ML, component, notification-assignment) rows behind each count. Read-only.
#   RAILS_ENV=test bin/rails runner .solve/scripts/trace-export-count-rows.rb

all_notification_ids = Current.without_organization_and_membership_scopes do
  NotificationComponentAssignment.unscoped.pluck(:notification_id).uniq
end

membership = Current.without_organization_and_membership_scopes do
  Membership.unscoped.find { |m| m.id == '7b90633e-ba16-5506-8c4c-4d4d85e31a7a' }
end

Current.set_from_membership(membership) do
  puts("filter notification_ids: #{all_notification_ids.size} ids (every notification with an assignment)")

  matching_mls = MonitoringList.visible.by_notifications(all_notification_ids).to_a
  puts("\nmatching MLs (#{matching_mls.size}):")
  matching_mls.each { |ml| puts("  #{ml.id}  #{ml.name}") }

  puts("\n--- every (ML, visible component) pair in those MLs, with its notification assignments ---")
  rows = []
  matching_mls.each do |ml|
    ml.visible_components.order(:id).each do |component|
      nca_ids = NotificationComponentAssignment.where(component_id: component.id).pluck(:notification_id)
      in_filter = nca_ids & all_notification_ids
      rows << { ml: ml.name, component: component.id, nca: in_filter }
      puts(
        "  ml=#{ml.name.to_s.ljust(22)} component=#{component.id.to_s.ljust(12)} " \
        "matching_notifications=#{in_filter.size} #{in_filter.inspect}"
      )
    end
  end

  pairs = rows.size
  pairs_with_notification = rows.count { |r| r[:nca].any? }
  triples = rows.sum { |r| r[:nca].size }

  puts("\n--- where each number comes from ---")
  puts("  (ML, component) pairs total .......................... #{pairs}   <- BEFORE: COUNT(*) over the export's own join")
  puts("  (ML, component) pairs having >=1 matching notification #{pairs_with_notification}   " \
       "<- .distinct.count('monitoring_lists_components.id')")
  puts("  (ML, component, notification) triples ................ #{triples}   <- .distinct(false): COUNT(*) with nca joined")
  puts("  distinct MLs ......................................... #{matching_mls.size}   " \
       '<- NOW: COUNT(DISTINCT monitoring_lists.id)')

  puts("\ncomponents with NO matching notification (present in BEFORE, absent in the join form):")
  rows.reject { |r| r[:nca].any? }.each { |r| puts("  ml=#{r[:ml]} component=#{r[:component]}") }

  puts("\ncomponents with MORE THAN ONE matching notification (cause the triple inflation):")
  rows.select { |r| r[:nca].size > 1 }.each { |r| puts("  ml=#{r[:ml]} component=#{r[:component]} notifications=#{r[:nca].size}") }
end
