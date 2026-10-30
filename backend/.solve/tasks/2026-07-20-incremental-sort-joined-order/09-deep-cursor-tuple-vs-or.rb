# The cache debate hinges on ONE thing: a cached column lives in the base table, so
# a row-value tuple keyset (cached_user_name, id) > (..) is a SINGLE-table index seek
# (sargable) — while the same tuple across the join is NOT. Test at a DEEP cursor
# (row 29000 of 30k) whether cached+tuple gives a true O(log n) seek. Rolled back.
#   bin/rails runner .solve/tasks/2026-07-20-incremental-sort-joined-order/09-deep-cursor-tuple-vs-or.rb

def conn = ActiveRecord::Base.connection

def report(label, sql)
  plan = conn.execute("EXPLAIN (ANALYZE) #{sql}").map { |r| r.values.first }
  scan = plan.grep(/Index Scan|Incremental|Sort|Seq Scan|Nested Loop/).first
  puts("  #{plan.grep(/Execution Time/).first.strip.sub('Execution Time: ', '').rjust(12)}   #{label}")
  puts("               #{scan&.strip}")
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

    join = "FROM memberships JOIN users ON users.id = memberships.user_id WHERE memberships.organization_id = #{org}"
    cur = conn.execute("SELECT users.name AS n, memberships.id AS i #{join} ORDER BY users.name, memberships.id OFFSET 24000 LIMIT 1").first
    n = conn.quote(cur['n'])
    i = conn.quote(cur['i'])

    puts("=== DEEP cursor (row 24000 of ~26.5k) ===")
    report('cached  TUPLE  (single-table row-value seek)',
      "SELECT memberships.* FROM memberships WHERE organization_id = #{org} AND (cached_user_name, id) > (#{n}, #{i}) ORDER BY cached_user_name, id LIMIT 26")
    report('cached  OR-expansion',
      "SELECT memberships.* FROM memberships WHERE organization_id = #{org} AND (cached_user_name > #{n} OR (cached_user_name = #{n} AND id > #{i})) ORDER BY cached_user_name, id LIMIT 26")
    report('join    TUPLE  (cross-table, NOT sargable)',
      "SELECT memberships.* #{join} AND (users.name, memberships.id) > (#{n}, #{i}) ORDER BY users.name, memberships.id LIMIT 26")
    report('join    OR-expansion (incremental sort)',
      "SELECT memberships.* #{join} AND (users.name > #{n} OR (users.name = #{n} AND memberships.id > #{i})) ORDER BY users.name, memberships.id LIMIT 26")

    raise(ActiveRecord::Rollback)
  end
end
