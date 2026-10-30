# Seed a small representative dataset with DatabaseSeeder, find the worst-case
# admin_expiry_summary item (largest membership_ids array), and measure show
# query cost. NAIVE is the current #description (single IN for memberships, but
# N+1 on users because Membership#email delegates to :user). PRELOADED resolves
# the same entries with includes(:user) — 2 queries flat.
# Runs inside a rolled-back transaction — non-destructive.
#   bin/rails runner .solve/scripts/seed-and-measure-admin-expiry.rb

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
      notification_events_per_org: 0,
      admin_expiry_items_per_org: 5,
      memberships_per_admin_expiry: 5..200
    ).run

    puts("Memberships:        #{Membership.unscoped.count}")
    puts("Admin expiry items: #{Membership::AdminExpirySummaryItem.unscoped.count}")
    puts('Per itemable class (inbox items / itemable rows):')
    Inbox::Item.unscoped.group(:itemable_type).count.sort.each do |type, item_count|
      puts("  #{type}: items=#{item_count} itemables=#{type.constantize.unscoped.count}")
    end
    puts

    worst = Membership::AdminExpirySummaryItem.unscoped
      .order(Arel.sql('cardinality(membership_ids) DESC'))
      .limit(1)
      .pick(:id)

    inbox_item = Inbox::Item.unscoped.find_by(
      itemable_type: 'Membership::AdminExpirySummaryItem',
      itemable_id: worst
    )

    entry_count = Membership::AdminExpirySummaryItem.unscoped.find(worst).membership_ids.size

    puts("Worst-case Membership::AdminExpirySummaryItem id=#{worst} (Inbox::Item id=#{inbox_item&.id})")
    puts("Membership entry count: #{entry_count}")
    puts

    naive = measure do
      item = Inbox::Item.unscoped.find(inbox_item.id)
      item.itemable.description
    end
    puts("NAIVE     (#description):   queries=#{naive[0]}  seconds=#{naive[1].round(4)}")

    GC.start

    preloaded_loaded = 0
    preloaded = measure do
      item = Inbox::Item.unscoped.find(inbox_item.id)
      itemable = item.itemable
      live = Membership.where(id: itemable.membership_ids).includes(:user).index_by(&:id)
      itemable.membership_ids.each do |id|
        preloaded_loaded += 1
        membership = live[id]
        [membership&.email, membership&.human_role, membership&.expires_at]
      end
      itemable.organization
    end
    puts("PRELOADED (includes): queries=#{preloaded[0]} seconds=#{preloaded[1].round(4)} loaded=#{preloaded_loaded}")

    raise(ActiveRecord::Rollback)
  end
end
