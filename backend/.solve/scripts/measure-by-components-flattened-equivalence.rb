# Prove the flattened `by_components` (components joined *inside* the join-table subquery)
# returns exactly the same ids as the current nested form, and measure the common literal-ids
# path so the rewrite is not a regression there. Rolled-back transaction — non-destructive.
#   bin/rails runner .solve/scripts/measure-by-components-flattened-equivalence.rb

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

def check(label, expected, actual)
  status = expected.sort == actual.sort ? 'SAME' : "DIFFERENT (#{expected.size} vs #{actual.size})"
  puts("  #{label.ljust(40)} #{status}")
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
      component_ids = MonitoringListsComponent.unscoped.where(organization_id: org.id)
        .limit(500).pluck(:component_id).uniq
      restricted_ids = Component.unscoped.where(tlp_amber_strict: true).limit(300).pluck(:id)
      mixed_ids = component_ids.first(200) + restricted_ids
      notification_ids = NotificationComponentAssignment.unscoped.limit(50).pluck(:notification_id).uniq
      ml_ids = MonitoringList.unscoped.where(organization_id: org.id).limit(20).pluck(:id)

      puts("org can_see_tlp_amber_strict=#{org.can_see_tlp_amber_strict}")
      puts("\n== equivalence (ids returned) ==")
      check(
        'ML.by_components literal',
        MonitoringList.visible.by_components(mixed_ids).ids,
        flat_ml.call(mixed_ids).ids
      )
      check(
        'ML.by_notifications',
        MonitoringList.visible.by_notifications(notification_ids).ids,
        flat_ml.call(NotificationComponentAssignment.where(notification_id: notification_ids).select(:component_id)).ids
      )
      check(
        'Notification.by_components literal',
        Notification.visible.by_components(mixed_ids).ids,
        flat_notification.call(mixed_ids).ids
      )
      check(
        'Notification.by_monitoring_lists',
        Notification.visible.by_monitoring_lists(ml_ids).ids,
        flat_notification.call(MonitoringListsComponent.where(monitoring_list_id: ml_ids).select(:component_id)).ids
      )

      puts("\n== literal-ids path (#{mixed_ids.size} ids), must not regress ==")
      puts('MonitoringList.by_components')
      summarize('current', MonitoringList.visible.by_components(mixed_ids).order(:id).limit(25))
      summarize('flattened', flat_ml.call(mixed_ids).order(:id).limit(25))
      puts('Notification.by_components')
      summarize('current', Notification.visible.by_components(mixed_ids).order(:id).limit(25))
      summarize('flattened', flat_notification.call(mixed_ids).order(:id).limit(25))

      puts("\nflattened SQL:\n#{flat_ml.call(mixed_ids.first(3)).order(:id).limit(25).to_sql}")
    end

    raise(ActiveRecord::Rollback)
  end
end
