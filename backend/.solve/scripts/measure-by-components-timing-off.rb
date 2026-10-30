# Re-measure subselect vs JOIN for the by_components family with EXPLAIN (ANALYZE, BUFFERS,
# TIMING OFF) so per-node instrumentation does not inflate the loop-heavy plans, and with
# parallelism disabled so both forms are comparable. Rolled-back transaction — non-destructive.
#   SCALE=1 bin/rails runner .solve/scripts/measure-by-components-timing-off.rb

SCALE = Integer(ENV.fetch('SCALE', 1))

def summarize(label, relation, parallel:)
  sql = relation.to_sql
  runs = ActiveRecord::Base.uncached do
    ActiveRecord::Base.connection.execute(
      "SET max_parallel_workers_per_gather = #{parallel ? 2 : 0}"
    )
    3.times.map do
      plan = ActiveRecord::Base.connection.select_values("EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) #{sql}")
      exec_ms = plan.grep(/Execution Time/).first.to_s[/[\d.]+/].to_f
      buffers = plan.grep(/Buffers: shared/).first.to_s.strip
      parallel_used = plan.grep(/Workers Launched/).first.to_s.strip
      [exec_ms, buffers, parallel_used]
    end
  end

  puts("  parallel=#{parallel ? 2 : 0} #{label.ljust(16)} exec_ms=#{runs.map(&:first).inspect}")
  puts("             #{' ' * 16} #{runs.first[1]}  #{runs.first[2]}")
end

def compare(title, subselect, join)
  puts("\n#{title}")
  [false, true].each do |parallel|
    summarize('subselect', subselect, parallel: parallel)
    summarize('join+distinct', join, parallel: parallel)
  end
end

Current.without_organization_and_membership_scopes do
  ActiveRecord::Base.transaction do
    DatabaseSeeder.new(
      organizations: 3,
      users: 300,
      memberships_per_user: 1..1,
      component_vendors: 200,
      component_names: 400,
      components: 20_000 * SCALE,
      notifications: 4_000 * SCALE,
      monitoring_list_per_org: 200 * SCALE,
      subscribers_per_ml: 1..5,
      components_per_ml: 20..200,
      inbox_items: 0,
      support_dropped_events: 0,
      ml_events_per_org: 0,
      notification_events_per_org: 0,
      notification_revisions_per_event: 0..0,
      notification_subscribers_per_event: 0..0
    ).run

    Component.unscoped.where(id: Component.unscoped.order('random()').limit(4_000 * SCALE).select(:id))
      .update_all(tlp_amber_strict: true)

    %w[
      components
      monitoring_lists_components
      notification_component_assignments
      monitoring_lists
      notifications
      organizations
].each do |table|
  ActiveRecord::Base.connection.execute("ANALYZE vilocifyportal.#{table}")
end
    ActiveRecord::Base.connection.execute('SET max_parallel_workers_per_gather = 0')

    puts(
      "SCALE=#{SCALE} components=#{Component.unscoped.count} mlc=#{MonitoringListsComponent.unscoped.count} " \
        "nca=#{NotificationComponentAssignment.unscoped.count} mls=#{MonitoringList.unscoped.count} " \
        "notifications=#{Notification.unscoped.count}"
    )

    org = Organization.unscoped.joins(:monitoring_lists).group('organizations.id')
      .order(Arel.sql('COUNT(monitoring_lists.id) DESC')).limit(1).first
    membership = Membership.unscoped.where(organization_id: org.id)
      .find { |m| m.permissions.include?('read:components') }

    Current.set_from_membership(membership) do
      component_ids = MonitoringListsComponent.unscoped.where(organization_id: org.id)
        .limit(500).pluck(:component_id).uniq
      notification_ids = NotificationComponentAssignment.unscoped.limit(50).pluck(:notification_id).uniq
      ml_ids = MonitoringList.unscoped.where(organization_id: org.id).limit(20).pluck(:id)

      compare(
        "MonitoringList.by_components (#{component_ids.size} ids)",
        MonitoringList.visible.by_components(component_ids).order(:id).limit(25),
        MonitoringList.visible.joins(:visible_components)
          .where(components: { id: component_ids }).distinct.order(:id).limit(25)
      )

      compare(
        "MonitoringList.by_notifications (#{notification_ids.size} ids)",
        MonitoringList.visible.by_notifications(notification_ids).order(:id).limit(25),
        MonitoringList.visible.joins(visible_components: :notification_component_assignments)
          .where(notification_component_assignments: { notification_id: notification_ids })
          .distinct.order(:id).limit(25)
      )

      compare(
        "Notification.by_components (#{component_ids.size} ids)",
        Notification.visible.by_components(component_ids).order(:id).limit(25),
        Notification.visible.joins(:visible_components)
          .where(components: { id: component_ids }).distinct.order(:id).limit(25)
      )

      compare(
        "Notification.by_monitoring_lists (#{ml_ids.size} ids)",
        Notification.visible.by_monitoring_lists(ml_ids).order(:id).limit(25),
        Notification.visible.joins(visible_components: :monitoring_lists_components)
          .where(monitoring_lists_components: { monitoring_list_id: ml_ids })
          .distinct.order(:id).limit(25)
      )
    end

    raise(ActiveRecord::Rollback)
  end
end
