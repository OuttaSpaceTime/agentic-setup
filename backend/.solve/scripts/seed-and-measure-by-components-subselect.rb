# Seed a realistic dataset, then compare the nested-subselect `by_components` /
# `by_notifications` / `by_monitoring_lists` scopes against the equivalent JOIN + DISTINCT
# form, with EXPLAIN ANALYZE and repeated timings. Rolled-back transaction — non-destructive.
#   bin/rails runner .solve/scripts/seed-and-measure-by-components-subselect.rb

def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

def explain(label, relation)
  sql = relation.to_sql
  plan = ActiveRecord::Base.connection.select_values("EXPLAIN (ANALYZE, BUFFERS) #{sql}")
  timings = 5.times.map do
    t = clock
    ActiveRecord::Base.connection.select_all(sql)
    ((clock - t) * 1000).round(2)
  end

  puts("── #{label}")
  puts(sql)
  puts(plan.join("\n"))
  puts("timings(ms): #{timings.inspect}  min=#{timings.min}  median=#{timings.sort[2]}")
  puts
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
].each do |table|
  ActiveRecord::Base.connection.execute("ANALYZE vilocifyportal.#{table}")
end

    puts("components:  #{Component.unscoped.count} (restricted: #{Component.unscoped.where(tlp_amber_strict: true).count})")
    puts("ml_components: #{MonitoringListsComponent.unscoped.count}")
    puts("nca:         #{NotificationComponentAssignment.unscoped.count}")
    puts("mls:         #{MonitoringList.unscoped.count}   notifications: #{Notification.unscoped.count}")
    puts

    org = Organization.unscoped.joins(:monitoring_lists).group('organizations.id')
      .order(Arel.sql('COUNT(monitoring_lists.id) DESC')).limit(1).first
    membership = Current.without_organization_and_membership_scopes do
      Membership.unscoped.where(organization_id: org.id).find { |m| m.permissions.include?('read:components') }
    end
    abort('no membership with read:components') if membership.nil?

    Current.set_from_membership(membership) do
      puts("org=#{org.id} membership=#{membership.id} tlp=#{org.can_see_tlp_amber_strict}")
      puts("permissions include read:tlp_amber_strict: #{Current.permissions.include?('read:tlp_amber_strict')}")
      puts

      few_component_ids = MonitoringListsComponent.unscoped.where(organization_id: org.id)
        .limit(5).pluck(:component_id)
      many_component_ids = MonitoringListsComponent.unscoped.where(organization_id: org.id)
        .limit(500).pluck(:component_id).uniq
      notification_ids = NotificationComponentAssignment.unscoped.limit(20).pluck(:notification_id).uniq
      ml_ids = MonitoringList.unscoped.where(organization_id: org.id).limit(20).pluck(:id)

      puts("=== MonitoringList.by_components (#{few_component_ids.size} ids) ===")
      explain('subselect (current)', MonitoringList.visible.by_components(few_component_ids).order(:id).limit(25))
      explain(
        'join + distinct',
        MonitoringList.visible.joins(:visible_components)
          .where(components: { id: few_component_ids }).distinct.order(:id).limit(25)
      )

      puts("=== MonitoringList.by_components (#{many_component_ids.size} ids) ===")
      explain('subselect (current)', MonitoringList.visible.by_components(many_component_ids).order(:id).limit(25))
      explain(
        'join + distinct',
        MonitoringList.visible.joins(:visible_components)
          .where(components: { id: many_component_ids }).distinct.order(:id).limit(25)
      )

      puts("=== MonitoringList.by_notifications (#{notification_ids.size} ids, deepest nest) ===")
      explain('subselect (current)', MonitoringList.visible.by_notifications(notification_ids).order(:id).limit(25))
      explain(
        'join + distinct',
        MonitoringList.visible.joins(visible_components: :notification_component_assignments)
          .where(notification_component_assignments: { notification_id: notification_ids })
          .distinct.order(:id).limit(25)
      )

      puts("=== Notification.by_components (#{many_component_ids.size} ids) ===")
      explain('subselect (current)', Notification.visible.by_components(many_component_ids).order(:id).limit(25))
      explain(
        'join + distinct',
        Notification.visible.joins(:visible_components)
          .where(components: { id: many_component_ids }).distinct.order(:id).limit(25)
      )

      puts("=== Notification.by_monitoring_lists (#{ml_ids.size} ids, deepest nest) ===")
      explain('subselect (current)', Notification.visible.by_monitoring_lists(ml_ids).order(:id).limit(25))
      explain(
        'join + distinct',
        Notification.visible.joins(visible_components: :monitoring_lists_components)
          .where(monitoring_lists_components: { monitoring_list_id: ml_ids })
          .distinct.order(:id).limit(25)
      )
    end

    raise(ActiveRecord::Rollback)
  end
end
