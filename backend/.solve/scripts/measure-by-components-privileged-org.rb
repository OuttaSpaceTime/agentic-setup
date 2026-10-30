# The decisive case for the flattened rewrite: an org that CAN see tlp_amber_strict.
# `Component.visible` is then `including_tlp_amber_strict` (an unscope), while `joins(:component)`
# bakes the default scope into the JOIN's ON clause. Check whether merge() can still undo it.
#   bin/rails runner .solve/scripts/measure-by-components-privileged-org.rb

def check(label, expected, actual)
  status = expected.sort == actual.sort ? 'SAME' : "DIFFERENT (current=#{expected.size} flat=#{actual.size})"
  puts("  #{label.ljust(38)} #{status}")
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
    org.reload
    membership = Membership.unscoped.where(organization_id: org.id)
      .find { |m| m.permissions.include?('read:components') }

    flat_ml = lambda do |ids|
      MonitoringList.visible.where(
        id: MonitoringListsComponent.joins(:component).merge(Component.visible)
          .where(component_id: ids).select(:monitoring_list_id)
      )
    end
    flat_notification = lambda do |ids|
      Notification.visible.where(
        id: NotificationComponentAssignment.joins(:component).merge(Component.visible)
          .where(component_id: ids).select(:notification_id)
      )
    end

    Current.set_from_membership(membership) do
      puts("org can_see_tlp_amber_strict=#{org.can_see_tlp_amber_strict}")
      puts("permissions include read:tlp_amber_strict=#{Current.permissions.include?('read:tlp_amber_strict')}")

      restricted_in_org = MonitoringListsComponent.unscoped.where(organization_id: org.id)
        .joins('JOIN vilocifyportal.components c ON c.id = monitoring_lists_components.component_id')
        .where('c.tlp_amber_strict')
        .pluck(:component_id).uniq
      puts("restricted components assigned in this org: #{restricted_in_org.size}")

      notification_ids = NotificationComponentAssignment.unscoped.limit(50).pluck(:notification_id).uniq
      ml_ids = MonitoringList.unscoped.where(organization_id: org.id).limit(20).pluck(:id)

      puts("\n== equivalence for a privileged org ==")
      check(
        'ML.by_components (restricted ids)',
        MonitoringList.visible.by_components(restricted_in_org).ids,
        flat_ml.call(restricted_in_org).ids
      )
      check(
        'ML.by_notifications',
        MonitoringList.visible.by_notifications(notification_ids).ids,
        flat_ml.call(NotificationComponentAssignment.where(notification_id: notification_ids).select(:component_id)).ids
      )
      check(
        'Notification.by_components (restricted)',
        Notification.visible.by_components(restricted_in_org).ids,
        flat_notification.call(restricted_in_org).ids
      )
      check(
        'Notification.by_monitoring_lists',
        Notification.visible.by_monitoring_lists(ml_ids).ids,
        flat_notification.call(MonitoringListsComponent.where(monitoring_list_id: ml_ids).select(:component_id)).ids
      )

      puts("\ncurrent SQL:\n#{MonitoringList.visible.by_components(restricted_in_org.first(2)).to_sql}")
      puts("\nflattened SQL:\n#{flat_ml.call(restricted_in_org.first(2)).to_sql}")
    end

    raise(ActiveRecord::Rollback)
  end
end
