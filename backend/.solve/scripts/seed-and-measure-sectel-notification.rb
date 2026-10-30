# Seed a small representative dataset with DatabaseSeeder, find the worst-case
# ml_notification item (~1000 revisions), and measure show query cost
# naive (N+1) vs preloaded. Runs inside a rolled-back transaction — non-destructive.
#   bin/rails runner .solve/scripts/seed-and-measure-sectel-notification.rb

def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

def measure
  count = 0
  sub = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
    count += 1 unless payload[:name] == 'SCHEMA' || payload[:sql] =~ /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i
  end
  t = clock
  yield
  [count, clock - t]
ensure
  ActiveSupport::Notifications.unsubscribe(sub)
end

Current.without_organization_and_membership_scopes do
  ActiveRecord::Base.transaction do
    DatabaseSeeder.new(
      organizations: 1,
      users: 200,
      memberships_per_user: 1..1,
      component_vendors: 50,
      component_names: 50,
      components: 200,
      notifications: 80,
      monitoring_list_per_org: 20,
      subscribers_per_ml: 5..15,
      components_per_ml: 5..20,
      inbox_items: 0,
      support_dropped_events: 0,
      ml_events_per_org: 0,
      notification_events_per_org: 5,
      notification_revisions_per_event: 3..1000,
      notification_subscribers_per_event: 3..15
    ).run

    puts("Notifications: #{Notification.unscoped.count}")
    puts("Revisions:     #{MonitoringList::NotificationRevision.unscoped.count}")
    puts("Inbox items:   #{Inbox::Item.unscoped.count}")
    puts('Per itemable class (inbox items / itemable rows):')
    Inbox::Item.unscoped.group(:itemable_type).count.sort.each do |type, item_count|
      puts("  #{type}: items=#{item_count} itemables=#{type.constantize.unscoped.count}")
    end
    puts

    worst = MonitoringList::NotificationItem.unscoped
      .joins('JOIN monitoring_list_notification_items_revisions j ON ' \
        'j.notification_item_id = monitoring_list_notification_items.id'
            )
      .group('monitoring_list_notification_items.id')
      .order(Arel.sql('COUNT(j.notification_revision_id) DESC'))
      .limit(1)
      .pick('monitoring_list_notification_items.id')

    inbox_item = Inbox::Item.unscoped.find_by(
      itemable_type: 'MonitoringList::NotificationItem',
      itemable_id: worst
    )

    revision_count = MonitoringList::NotificationItem.unscoped.find(worst).notification_revisions.count

    puts("Worst-case MonitoringList::NotificationItem id=#{worst} (Inbox::Item id=#{inbox_item&.id})")
    puts("Revision count: #{revision_count}")
    puts

    naive_loaded = 0
    naive = measure do
      item = Inbox::Item.unscoped.find(inbox_item.id)
      itemable = item.itemable
      itemable.notification_revisions.each do |revision|
        naive_loaded += 1
        [revision.notification&.title, revision.history_summary]
      end
      itemable.event
    end
    puts("NAIVE     (no preload): queries=#{naive[0]}  seconds=#{naive[1].round(4)}  loaded=#{naive_loaded}")

    GC.start

    preloaded_loaded = 0
    preloaded = measure do
      item = Inbox::Item.unscoped.includes(itemable: :event).find(inbox_item.id)
      itemable = item.itemable
      itemable.notification_revisions.includes(:notification).each do |revision|
        preloaded_loaded += 1
        [revision.notification&.title, revision.history_summary]
      end
      itemable.event
    end
    puts("PRELOADED (includes): queries=#{preloaded[0]} seconds=#{preloaded[1].round(4)} loaded=#{preloaded_loaded}")

    raise(ActiveRecord::Rollback)
  end
end
