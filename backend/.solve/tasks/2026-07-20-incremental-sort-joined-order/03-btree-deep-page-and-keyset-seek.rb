# With a btree on the joined column, is the joined ORDER BY (base id tiebreaker)
# fast BEYOND page 1 — i.e. a deep offset page and a keyset-style seek to the
# middle? This is the pagination case #1123 actually cares about. Rolled back.
#   bin/rails runner .solve/tasks/2026-07-20-incremental-sort-joined-order/03-btree-deep-page-and-keyset-seek.rb

def conn = ActiveRecord::Base.connection

def report(label, sql)
  plan = conn.execute("EXPLAIN (ANALYZE, BUFFERS) #{sql}").map { |r| r.values.first }
  puts("=== #{label} ===")
  plan.grep(/Sort|Scan|Nested Loop|Hash Join|Limit|Incremental/).first(6).each { |l| puts("   #{l.strip}") }
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

    conn.execute('CREATE INDEX idx_vendor_name_btree ON component_vendors (name)')
    conn.execute('ANALYZE components, component_vendors')

    base = <<~SQL.squish
      SELECT components.* FROM components
      JOIN component_vendors ON component_vendors.id = components.component_vendor_id
    SQL
    order = 'ORDER BY component_vendors.name ASC, components.id ASC'

    cursor_name, cursor_id = conn.execute(
      "#{base} #{order} LIMIT 1 OFFSET 10000"
    ).first.values_at('name', 'id') rescue nil
    mid = conn.execute("#{base} #{order} OFFSET 10000 LIMIT 1")
    row = mid.first
    cname = conn.execute("SELECT name FROM component_vendors v JOIN components c ON c.component_vendor_id=v.id WHERE c.id=#{row['id']}").first['name']

    report('page 1                (LIMIT 25 OFFSET 0)', "#{base} #{order} LIMIT 25")
    report('deep offset page      (LIMIT 25 OFFSET 10000)', "#{base} #{order} LIMIT 25 OFFSET 10000")
    report('keyset seek to middle (row-value > cursor)',
      "#{base} WHERE (component_vendors.name, components.id) > (#{conn.quote(cname)}, #{row['id']}) #{order} LIMIT 25")

    raise(ActiveRecord::Rollback)
  end
end
