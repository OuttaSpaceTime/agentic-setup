# Proof for the Membership user_name keyset:
#   (A) the btree indexes on users(name/email) really exist  -> read pg_indexes
#   (B) what plan the real keyset query uses (incremental sort? seek?),
#       tuple_comparison form vs OR-expansion, incremental sort ON vs OFF.
# Seeds ~30k memberships in ONE org so the planner has a real choice. Rolled back.
#   bin/rails runner .solve/tasks/2026-07-20-incremental-sort-joined-order/04-membership-keyset-proof.rb

def conn = ActiveRecord::Base.connection

def report(label, sql, incremental:)
  conn.execute("SET LOCAL enable_incremental_sort = #{incremental ? 'on' : 'off'}")
  plan = conn.execute("EXPLAIN (ANALYZE, BUFFERS) #{sql}").map { |r| r.values.first }
  puts("  [incr #{incremental ? 'ON ' : 'OFF'}] #{label}")
  plan.grep(/Sort|Scan|Nested Loop|Hash Join|Merge Join|Limit|Incremental/).first(6).each { |l| puts("      #{l.strip}") }
  puts("      #{plan.grep(/Execution Time/).first&.strip}")
end

Current.without_organization_and_membership_scopes do
  ActiveRecord::Base.transaction do
    puts('=== (A) btree indexes on users (straight from pg_indexes) ===')
    conn.execute("SELECT indexdef FROM pg_indexes WHERE tablename = 'users' ORDER BY indexname")
      .each { |r| puts("   #{r['indexdef']}") }
    puts

    seeder = DatabaseSeeder.new(
      organizations: 1, users: 30_000, memberships_per_user: 1..1,
      component_vendors: 10, component_names: 10, components: 10,
      notifications: 0, monitoring_list_per_org: 0, subscribers_per_ml: 0..0,
      components_per_ml: 0..0, inbox_items: 0, support_dropped_events: 0,
      ml_events_per_org: 0, notification_events_per_org: 0, admin_expiry_items_per_org: 0
    )
    seeder.run
    conn.execute('ANALYZE users, memberships')

    org = seeder.org_ids.first
    total = Membership.unscoped.where(organization_id: org).count
    puts("=== (B) memberships in org: #{total} ===")

    base  = "SELECT memberships.* FROM memberships JOIN users ON users.id = memberships.user_id WHERE memberships.organization_id = #{conn.quote(org)}"
    order = 'ORDER BY users.name ASC, memberships.id ASC'
    cur = conn.execute("SELECT users.name AS n, memberships.id AS i FROM memberships JOIN users ON users.id = memberships.user_id WHERE memberships.organization_id = #{conn.quote(org)} #{order} OFFSET #{total / 2} LIMIT 1").first
    cn = conn.quote(cur['n'])
    ci = conn.quote(cur['i'])

    queries = {
      'page 1 (no cursor)'                     => "#{base} #{order} LIMIT 25",
      'deep OFFSET (the thing we replace)'     => "#{base} #{order} LIMIT 25 OFFSET #{total / 2}",
      'keyset TUPLE  (row-value > cursor)'     => %(#{base} AND (users.name, memberships.id) > (#{cn}, #{ci}) #{order} LIMIT 25),
      'keyset OR-expansion (same cursor)'      => %(#{base} AND (users.name > #{cn} OR (users.name = #{cn} AND memberships.id > #{ci})) #{order} LIMIT 25)
    }

    queries.each do |label, sql|
      puts("--- #{label} ---")
      report(label, sql, incremental: true)
      report(label, sql, incremental: false)
      puts
    end

    raise(ActiveRecord::Rollback)
  end
end
