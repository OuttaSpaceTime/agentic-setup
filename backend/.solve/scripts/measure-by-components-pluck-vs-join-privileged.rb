# For a privileged org (can_see_tlp_amber_strict), check which rewrite of the two NESTING scopes
# preserves the current result set: the reviewer's joins(:visible_components) + distinct, or
# materializing the inner ids with pluck (leaving by_components untouched).
#   bin/rails runner .solve/scripts/measure-by-components-pluck-vs-join-privileged.rb

def check(label, expected, actual)
  status = expected.sort == actual.sort ? 'SAME' : "DIFFERENT (current=#{expected.size} variant=#{actual.size})"
  puts("  #{label.ljust(46)} #{status}")
end

Current.without_organization_and_membership_scopes do
  ActiveRecord::Base.transaction do
    DatabaseSeeder.new(
      organizations: 2, users: 100, memberships_per_user: 1..1,
      component_vendors: 50, component_names: 100, components: 3_000,
      notifications: 600, monitoring_list_per_org: 40,
      subscribers_per_ml: 1..5, components_per_ml: 20..100,
      inbox_items: 0, support_dropped_events: 0, ml_events_per_org: 0,
      notification_events_per_org: 0, notification_revisions_per_event: 0..0,
      notification_subscribers_per_event: 0..0
    ).run

    Component.unscoped.where(id: Component.unscoped.order('random()').limit(900).select(:id))
      .update_all(tlp_amber_strict: true)

    org = Organization.unscoped.joins(:monitoring_lists).group('organizations.id')
      .order(Arel.sql('COUNT(monitoring_lists.id) DESC')).limit(1).first
    Organization.unscoped.where(id: org.id).update_all(can_see_tlp_amber_strict: true)
    membership = Membership.unscoped.where(organization_id: org.id)
      .find { |m| m.permissions.include?('read:components') }

    Current.set_from_membership(membership) do
      puts("read:tlp_amber_strict=#{Current.permissions.include?('read:tlp_amber_strict')}")
      notification_ids = NotificationComponentAssignment.unscoped.limit(50).pluck(:notification_id).uniq
      ml_ids = MonitoringList.unscoped.where(organization_id: org.id).limit(20).pluck(:id)

      puts("\n== MonitoringList.by_notifications (#{notification_ids.size} ids) ==")
      current = MonitoringList.visible.by_notifications(notification_ids).ids
      check(
        'joins(:visible_components)+distinct',
        current,
        MonitoringList.visible.joins(visible_components: :notification_component_assignments)
          .where(notification_component_assignments: { notification_id: notification_ids }).distinct.ids
      )
      check(
        'pluck inner ids',
        current,
        MonitoringList.visible.by_components(
          NotificationComponentAssignment.where(notification_id: notification_ids).pluck(:component_id)
        ).ids
      )

      puts("\n== Notification.by_monitoring_lists (#{ml_ids.size} ids) ==")
      current = Notification.visible.by_monitoring_lists(ml_ids).ids
      check(
        'joins(:visible_components)+distinct',
        current,
        Notification.visible.joins(visible_components: :monitoring_lists_components)
          .where(monitoring_lists_components: { monitoring_list_id: ml_ids }).distinct.ids
      )
      check(
        'pluck inner ids',
        current,
        Notification.visible.by_components(
          MonitoringListsComponent.where(monitoring_list_id: ml_ids).pluck(:component_id)
        ).ids
      )

      puts("\njoins(:visible_components) SQL fragment:")
      puts(Notification.visible.joins(:visible_components).to_sql[/INNER JOIN "components".*?(?= WHERE)/])
    end

    raise(ActiveRecord::Rollback)
  end
end
