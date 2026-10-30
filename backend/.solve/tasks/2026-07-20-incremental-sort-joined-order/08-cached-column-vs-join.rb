# Fair comparison for "slow vs fast vs fast enough" on Membership user_name,
# 30k memberships in one org. Three approaches, page 1 AND a mid-page cursor:
#   (1) current LEFT-join (the "slow" baseline)
#   (2) INNER-join + existing users.name btree  (incremental sort, no cache)
#   (3) cached column on memberships + composite index (Niklas's denormalization)
# EXPLAIN ANALYZE each; watch for full sort / disk spill vs index seek. Rolled back.
#   bin/rails runner .solve/tasks/2026-07-20-incremental-sort-joined-order/08-cached-column-vs-join.rb

def conn = ActiveRecord::Base.connection

def report(label, sql)
  plan = conn.execute("EXPLAIN (ANALYZE, BUFFERS) #{sql}").map { |r| r.values.first }
  puts("--- #{label} ---")
  plan.grep(/Sort|Scan|Nested Loop|Hash Join|Limit|Incremental|Disk/).first(5).each { |l| puts("   #{l.strip}") }
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

    conn.execute('ALTER TABLE memberships ADD COLUMN cached_user_name varchar')
    conn.execute("UPDATE memberships SET cached_user_name = users.name FROM users WHERE users.id = memberships.user_id AND memberships.organization_id = #{org}")
    conn.execute('CREATE INDEX idx_mem_cached ON memberships (organization_id, cached_user_name, id)')
    conn.execute('ANALYZE users, memberships')

    join   = "FROM memberships JOIN users ON users.id = memberships.user_id WHERE memberships.organization_id = #{org}"
    ljoin  = "FROM memberships LEFT OUTER JOIN users ON users.id = memberships.user_id WHERE memberships.organization_id = #{org}"
    cur = conn.execute("SELECT users.name AS n, memberships.id AS i #{join} ORDER BY users.name, memberships.id OFFSET 15000 LIMIT 1").first
    cn = conn.quote(cur['n'])
    ci = conn.quote(cur['i'])

    puts("=== PAGE 1 ===")
    report('(1) LEFT join, no cache (current, slow)',   "SELECT memberships.* #{ljoin} ORDER BY users.name, memberships.id LIMIT 26")
    report('(2) INNER join + users.name btree',          "SELECT memberships.* #{join} ORDER BY users.name, memberships.id LIMIT 26")
    report('(3) cached column + composite index',        "SELECT memberships.* FROM memberships WHERE organization_id = #{org} ORDER BY cached_user_name, id LIMIT 26")

    puts("=== MID-PAGE CURSOR (row 15000) ===")
    report('(2) INNER join keyset (OR-expansion)',       "SELECT memberships.* #{join} AND (users.name > #{cn} OR (users.name = #{cn} AND memberships.id > #{ci})) ORDER BY users.name, memberships.id LIMIT 26")
    report('(3) cached column keyset (OR-expansion)',    "SELECT memberships.* FROM memberships WHERE organization_id = #{org} AND (cached_user_name > #{cn} OR (cached_user_name = #{cn} AND id > #{ci})) ORDER BY cached_user_name, id LIMIT 26")

    raise(ActiveRecord::Rollback)
  end
end
