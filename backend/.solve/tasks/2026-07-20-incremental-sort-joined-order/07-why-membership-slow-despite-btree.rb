# Membership has a btree on users.name, yet the existing endpoint's page 1 is 16 ms.
# Is the cause the includes(:user) eager_load LEFT-JOIN shape (memberships-driven,
# can't use the users.name index), vs an INNER join the planner can drive off the
# index? Compares the 3 shapes with EXPLAIN ANALYZE. Rolled back.
#   bin/rails runner .solve/tasks/2026-07-20-incremental-sort-joined-order/07-why-membership-slow-despite-btree.rb

def conn = ActiveRecord::Base.connection

def report(label, sql)
  plan = conn.execute("EXPLAIN (ANALYZE, BUFFERS) #{sql}").map { |r| r.values.first }
  puts("=== #{label} ===")
  plan.grep(/Sort|Scan|Nested Loop|Hash Join|Merge Join|Limit|Incremental/).first(6).each { |l| puts("   #{l.strip}") }
  puts("   #{plan.grep(/Execution Time/).first&.strip}\n\n")
end

Current.without_organization_and_membership_scopes do
  ActiveRecord::Base.transaction do
    seeder = DatabaseSeeder.new(
      organizations: 1, users: 30_000, memberships_per_user: 1..1,
      component_vendors: 10, component_names: 10, components: 10,
      notifications: 0, monitoring_list_per_org: 0, subscribers_per_ml: 0..0,
      components_per_ml: 0..0, inbox_items: 0, support_dropped_events: 0,
      ml_events_per_org: 0, notification_events_per_org: 0, admin_expiry_items_per_org: 0
    )
    seeder.run
    org = conn.quote(seeder.org_ids.first)
    conn.execute('ANALYZE users, memberships')
    order = 'ORDER BY users.name ASC, memberships.id ASC LIMIT 26'

    report('LEFT OUTER JOIN, wide select (what includes(:user) does)',
      "SELECT memberships.*, users.* FROM memberships LEFT OUTER JOIN users ON users.id = memberships.user_id WHERE memberships.organization_id = #{org} #{order}")
    report('INNER JOIN, wide select (isolates width)',
      "SELECT memberships.*, users.* FROM memberships INNER JOIN users ON users.id = memberships.user_id WHERE memberships.organization_id = #{org} #{order}")
    report('INNER JOIN, narrow select (what joins(:user) does)',
      "SELECT memberships.* FROM memberships INNER JOIN users ON users.id = memberships.user_id WHERE memberships.organization_id = #{org} #{order}")

    raise(ActiveRecord::Rollback)
  end
end
