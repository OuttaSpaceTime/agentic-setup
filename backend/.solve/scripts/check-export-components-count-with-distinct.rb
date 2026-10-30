# ExcelManager#components_count does `@monitoring_lists.joins(:visible_components).size`.
# by_notifications now carries `.distinct`, which is sticky. Show what COUNT that produces
# versus the pre-change (non-distinct) relation. Read-only.
#   RAILS_ENV=test bin/rails runner .solve/scripts/check-export-components-count-with-distinct.rb

sqls = []
ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
  sqls << payload[:sql] if payload[:sql] =~ /COUNT/i
end

all_notification_ids = Current.without_organization_and_membership_scopes do
  NotificationComponentAssignment.unscoped.pluck(:notification_id).uniq
end

candidates = Current.without_organization_and_membership_scopes do
  Membership.unscoped.select { |m| m.permissions.include?('read:components') }
end

membership = candidates.find do |m|
  Current.set_from_membership(m) do
    MonitoringList.visible.by_notifications(all_notification_ids).joins(:visible_components).distinct(false).count.positive?
  end
end
abort('no membership matches any ML via notifications filter') if membership.nil?
puts("membership=#{membership.id} org=#{membership.organization_id}")

Current.set_from_membership(membership) do
  notification_ids = Current.without_organization_and_membership_scopes do
    NotificationComponentAssignment.unscoped.pluck(:notification_id).uniq
  end

  filtered = MonitoringList.visible.by_notifications(notification_ids)
  puts("matching MLs: #{filtered.count}")

  sqls.clear
  with_distinct = filtered.joins(:visible_components).size
  puts("\ncomponents_count NOW (distinct sticky): #{with_distinct}")
  puts("  SQL: #{sqls.last}")

  sqls.clear
  without_distinct = MonitoringList.visible
    .where(
      id: MonitoringListsComponent.where(
        component: Component.visible.where(
          id: NotificationComponentAssignment.where(notification_id: notification_ids).select(:component_id)
        )
      ).select(:monitoring_list_id)
    )
    .joins(:visible_components).size
  puts("\ncomponents_count BEFORE (subselect form): #{without_distinct}")
  puts("  SQL: #{sqls.last}")

  puts("\nverdict: #{with_distinct == without_distinct ? 'unchanged' : 'CHANGED — export size guard now counts MLs, not ML-component pairs'}")

  puts("\ncandidate fixes against the new relation:")
  puts("  .distinct(false).size                              = #{filtered.joins(:visible_components).distinct(false).size}")
  puts("  .distinct.count('monitoring_lists_components.id')  = " \
       "#{filtered.joins(:visible_components).distinct.count('monitoring_lists_components.id')}")
  puts("  target (pre-change value)                          = #{without_distinct}")
end
