# Benchmark: how slow is sorting on a joined column, and does Postgres incremental
# sort rescue it? Seeds a realistic dataset in a rolled-back transaction, then runs
# EXPLAIN (ANALYZE) for each sort with enable_incremental_sort ON vs OFF, at page 1
# and at a deep offset. Non-destructive.
#   bin/rails runner .solve/tasks/2026-07-20-incremental-sort-joined-order/01-benchmark-joined-sort-incremental.rb

LIMIT = 25

def conn = ActiveRecord::Base.connection

def explain(relation, incremental:)
  conn.execute("SET LOCAL enable_incremental_sort = #{incremental ? 'on' : 'off'}")
  conn.execute("EXPLAIN (ANALYZE, BUFFERS) #{relation.to_sql}").map { |r| r.values.first }
end

def report(label, relation)
  [true, false].each do |incremental|
    plan = explain(relation, incremental: incremental)
    top  = plan.grep(/Sort|Scan|Nested Loop|Hash Join|Merge Join|Limit/).first(5)
    exec = plan.grep(/Execution Time/).first
    puts("  [incr #{incremental ? 'ON ' : 'OFF'}] #{label}")
    top.each { |line| puts("      #{line.strip}") }
    puts("      #{exec&.strip}")
  end
  puts
end

Current.without_organization_and_membership_scopes do
  ActiveRecord::Base.transaction do
    seeder = DatabaseSeeder.new(
      organizations: 1, users: 3_000, memberships_per_user: 1..1,
      component_vendors: 4_000, component_names: 4_000, components: 20_000,
      notifications: 0, monitoring_list_per_org: 0, subscribers_per_ml: 0..0,
      components_per_ml: 0..0, inbox_items: 0, support_dropped_events: 0,
      ml_events_per_org: 0, notification_events_per_org: 0, admin_expiry_items_per_org: 0
    )
    seeder.run
    org_id = seeder.org_ids.first

    puts("PG version: #{conn.select_value('SHOW server_version')}")
    puts("default enable_incremental_sort: #{conn.select_value('SHOW enable_incremental_sort')}")
    comp_total = Component.count
    mem_total  = Membership.where(organization_id: org_id).count
    puts("components=#{comp_total}  memberships(org)=#{mem_total}")
    puts

    comp = Component.joins(:component_vendor, :component_name)
    mem  = Membership.where(organization_id: org_id).joins(:user)

    sorts = {
      'Component  ORDER BY vendor.name, id  (no btree)' => [comp.reorder('component_vendors.name ASC, components.id ASC'), comp_total],
      'Component  ORDER BY name.name, id    (no btree)' => [comp.reorder('component_names.name ASC, components.id ASC'), comp_total],
      'Component  ORDER BY components.id     (baseline)' => [comp.reorder('components.id ASC'), comp_total],
      'Membership ORDER BY users.name, id   (btree)'    => [mem.reorder('users.name ASC, memberships.id ASC'), mem_total],
      'Membership ORDER BY users.email, id  (btree)'    => [mem.reorder('users.email ASC, memberships.id ASC'), mem_total],
      'Membership ORDER BY memberships.id    (baseline)' => [mem.reorder('memberships.id ASC'), mem_total]
    }

    sorts.each do |label, (relation, total)|
      deep = [total - LIMIT, 0].max
      puts("=== #{label} ===")
      report("page 1 (LIMIT #{LIMIT} OFFSET 0)", relation.limit(LIMIT))
      report("deep    (LIMIT #{LIMIT} OFFSET #{deep})", relation.limit(LIMIT).offset(deep))
    end

    raise(ActiveRecord::Rollback)
  end
end
