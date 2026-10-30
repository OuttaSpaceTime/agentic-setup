# For the two scopes that nest a subselect inside a subselect (by_notifications /
# by_monitoring_lists), compare the current 4-level form against candidate rewrites:
# a JOIN+DISTINCT, a flattened form that joins components *inside* the join-table subquery,
# and a pluck form that materializes ids. Rolled-back transaction — non-destructive.
#   bin/rails runner .solve/scripts/measure-by-components-fix-variants.rb

def summarize(label, relation)
  sql = relation.to_sql
  runs = ActiveRecord::Base.uncached do
    3.times.map do
      plan = ActiveRecord::Base.connection.select_values("EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) #{sql}")
      [plan.grep(/Execution Time/).first.to_s[/[\d.]+/].to_f, plan.grep(/Buffers: shared/).first.to_s.strip]
    end
  end
  puts("  #{label.ljust(24)} exec_ms=#{runs.map(&:first).inspect}  #{runs.first[1]}")
end

Current.without_organization_and_membership_scopes do
  ActiveRecord::Base.transaction do
    DatabaseSeeder.new(
      organizations: 3,
      users: 300,
      memberships_per_user: 1..1,
      component_vendors: 200,
      component_names: 400,
      components: 20_000,
      notifications: 4_000,
      monitoring_list_per_org: 200,
      subscribers_per_ml: 1..5,
      components_per_ml: 20..200,
      inbox_items: 0,
      support_dropped_events: 0,
      ml_events_per_org: 0,
      notification_events_per_org: 0,
      notification_revisions_per_event: 0..0,
      notification_subscribers_per_event: 0..0
    ).run

    Component.unscoped.where(id: Component.unscoped.order('random()').limit(4_000).select(:id))
      .update_all(tlp_amber_strict: true)
    %w[
      components
      monitoring_lists_components
      notification_component_assignments
      monitoring_lists
      notifications
      organizations
].each do |t|
  ActiveRecord::Base.connection.execute("ANALYZE vilocifyportal.#{t}")
end

    org = Organization.unscoped.joins(:monitoring_lists).group('organizations.id')
      .order(Arel.sql('COUNT(monitoring_lists.id) DESC')).limit(1).first
    membership = Membership.unscoped.where(organization_id: org.id)
      .find { |m| m.permissions.include?('read:components') }

    Current.set_from_membership(membership) do
      notification_ids = NotificationComponentAssignment.unscoped.limit(50).pluck(:notification_id).uniq
      ml_ids = MonitoringList.unscoped.where(organization_id: org.id).limit(20).pluck(:id)

      puts("MonitoringList.by_notifications (#{notification_ids.size} ids)")
      nca_component_ids = NotificationComponentAssignment.where(notification_id: notification_ids)
        .select(:component_id)
      summarize('current (4 levels)', MonitoringList.visible.by_notifications(notification_ids).order(:id).limit(25))
      summarize(
        'join+distinct',
        MonitoringList.visible.joins(visible_components: :notification_component_assignments)
          .where(notification_component_assignments: { notification_id: notification_ids })
          .distinct.order(:id).limit(25)
      )
      summarize(
        'flattened join-in-sub',
        MonitoringList.visible.where(
          id: MonitoringListsComponent.joins(:component).merge(Component.visible)
            .where(component_id: nca_component_ids).select(:monitoring_list_id)
        ).order(:id).limit(25)
      )
      summarize(
        'pluck ids',
        MonitoringList.visible.by_components(
          NotificationComponentAssignment.where(notification_id: notification_ids).pluck(:component_id)
        ).order(:id).limit(25)
      )

      puts("\nNotification.by_monitoring_lists (#{ml_ids.size} ids)")
      mlc_component_ids = MonitoringListsComponent.where(monitoring_list_id: ml_ids).select(:component_id)
      summarize('current (4 levels)', Notification.visible.by_monitoring_lists(ml_ids).order(:id).limit(25))
      summarize(
        'join+distinct',
        Notification.visible.joins(visible_components: :monitoring_lists_components)
          .where(monitoring_lists_components: { monitoring_list_id: ml_ids })
          .distinct.order(:id).limit(25)
      )
      summarize(
        'flattened join-in-sub',
        Notification.visible.where(
          id: NotificationComponentAssignment.joins(:component).merge(Component.visible)
            .where(component_id: mlc_component_ids).select(:notification_id)
        ).order(:id).limit(25)
      )
      summarize(
        'pluck ids',
        Notification.visible.by_components(
          MonitoringListsComponent.where(monitoring_list_id: ml_ids).pluck(:component_id)
        ).order(:id).limit(25)
      )
    end

    raise(ActiveRecord::Rollback)
  end
end
