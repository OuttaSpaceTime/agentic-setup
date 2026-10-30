# Follow-up: script 01 showed incremental sort NEVER fires for the joined sorts
# (the planner picks a Hash Join, which destroys input order, so there is no sorted
# prefix to feed incremental sort). This asks: if we add a btree on the joined
# leading column, does the planner switch to an ordered index scan that unlocks
# incremental sort / early termination for page 1? Non-destructive (rolled back).
#   bin/rails runner .solve/tasks/2026-07-20-incremental-sort-joined-order/02-would-a-btree-unlock-incremental-sort.rb

def conn = ActiveRecord::Base.connection

def explain(relation)
  conn.execute("EXPLAIN (ANALYZE, BUFFERS) #{relation.to_sql}").map { |r| r.values.first }
end

def report(label, relation)
  plan = explain(relation)
  puts("=== #{label} ===")
  plan.grep(/Sort|Scan|Nested Loop|Hash Join|Merge Join|Limit|Incremental/).first(7).each { |l| puts("   #{l.strip}") }
  puts("   #{plan.grep(/Execution Time/).first&.strip}")
  puts
end

Current.without_organization_and_membership_scopes do
  ActiveRecord::Base.transaction do
    DatabaseSeeder.new(
      organizations: 1, users: 100, memberships_per_user: 1..1,
      component_vendors: 4_000, component_names: 4_000, components: 20_000,
      notifications: 0, monitoring_list_per_org: 0, subscribers_per_ml: 0..0,
      components_per_ml: 0..0, inbox_items: 0, support_dropped_events: 0,
      ml_events_per_org: 0, notification_events_per_org: 0, admin_expiry_items_per_org: 0
    ).run

    vendor_sort = Component.joins(:component_vendor)
      .reorder('component_vendors.name ASC, components.id ASC').limit(25)

    conn.execute('ANALYZE components, component_vendors')
    report('BEFORE btree — Component ORDER BY vendor.name, id  (page 1)', vendor_sort)

    conn.execute('CREATE INDEX idx_vendor_name_btree ON component_vendors (name)')
    conn.execute('ANALYZE component_vendors')
    report('AFTER  btree — Component ORDER BY vendor.name, id  (page 1)', vendor_sort)

    raise(ActiveRecord::Rollback)
  end
end
