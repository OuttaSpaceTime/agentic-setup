# Walks every paginated collection endpoint's sort keys through the real Keyset::Page/Keyset::Cursor
# code path and compares the concatenated pages against the same query run unpaginated.
#
#   bin/rails runner .solve/scripts/check_keyset_sorting.rb
#   PAGE_SIZES=3,50 bin/rails runner .solve/scripts/check_keyset_sorting.rb

PAGE_SIZES = ENV.fetch('PAGE_SIZES', '1,3,7,50').split(',').map(&:to_i)
MAX_PAGES = 1000

organization = Current.without_organization_and_membership_scopes { Organization.find_by!(name: 'Organization A') }
seed_membership = Current.without_organization_and_membership_scopes do
  Membership.find_by!(organization: organization, role: 'admin', user: User.find_by!(email: 'superuser@example.com'))
end

# Mirrors the controller, which hands Pagination::Params an indifferent-access params hash.
def page_params(size, after)
  params = Pagination::Params.new({ size: size.to_s, after: after }.compact.with_indifferent_access)
  params.validate!
  params
end

def walk_pages(sorted, size)
  collected = []
  after = nil

  MAX_PAGES.times do
    cursor, records = Keyset::Page.new(sorted, page_params(size, after)).page
    collected.concat(records)
    return collected unless cursor

    after = cursor
  end

  raise("did not terminate after #{MAX_PAGES} pages")
end

def report_case(_label, sort_param, sorted, sizes)
  # The paginator reorders by its own sort expressions (COALESCE sentinels, declared SQL), so the
  # unpaginated baseline has to use the same clause rather than json_api_sort's bare columns.
  columns = Keyset::Columns.of(sorted)
  baseline = sorted.reorder(Arel.sql(columns.order_clause)).to_a
  baseline_ids = baseline.map(&:id)

  sizes.each do |size|
    walked_ids = walk_pages(sorted, size).map(&:id)
    duplicates = walked_ids.tally.select { |_id, count| count > 1 }.keys
    missing = baseline_ids - walked_ids

    if walked_ids == baseline_ids
      puts(
        format(
          '  PASS  %-22s size=%-3d %d records, %d pages',
          sort_param,
          size,
          walked_ids.size,
          walked_ids.size.fdiv(size).ceil
        )
      )
    else
      puts(
        format(
          '  FAIL  %-22s size=%-3d walked=%d baseline=%d duplicated=%d missing=%d',
          sort_param,
          size,
          walked_ids.size,
          baseline_ids.size,
          duplicates.size,
          missing.size
        )
      )
      puts(
        format(
          '        first divergence at index %s',
          walked_ids.zip(baseline_ids).index { |walked, expected| walked != expected }
        )
      )
    end
  end

  sample = columns.map { |column| baseline.first(3).map { |record| column.cursor_value_of(record).inspect } }
  puts(format('        leading values %s', sample.inspect))
rescue Keyset::Columns::NotSeekable => e
  puts(format('  REFUSED %-20s %s', sort_param, e.message))
rescue Keyset::InvalidCursor
  puts(format('  INVALID CURSOR %-13s', sort_param))
end

Current.set(organization: organization, membership: seed_membership) do
  pivot_component = Component.find(2_000_000_000)
  pivot_notification = Notification.find(2_100_000_000)
  pivot_list = MonitoringList.visible.find_by!(comment: '[keyset-sort-seed]', name: 'Seed List blank 000')
  parent_pivot_list = MonitoringList.visible.where(comment: '[keyset-sort-seed]').order(:created_at).last

  cases = [
    ['/components', -> { Component.visible }, Component.orderable_columns - %w[relevance]],
    ['/components?filter[search][is]=Seed', -> { Component.visible.search('Seed') }, %w[relevance id name]],
    ['/notifications', -> { Notification.visible }, Notification.orderable_columns],
    ['/vulnerabilities', -> { Notification::Vulnerability.visible }, Notification::Vulnerability.orderable_columns],
    ['/monitoring_lists', -> { MonitoringList.visible }, MonitoringList.orderable_columns],
    ['/component_requests', -> { ComponentRequest.visible }, ComponentRequest.orderable_columns],
    ['/memberships', -> { Membership.visible }, Membership.orderable_columns],
    ['/subscriptions', -> { Subscription.visible }, Subscription.orderable_columns],
    ['/api_tokens', -> { ApiToken.all }, ApiToken.orderable_columns],
    ['/inbox/items', -> { seed_membership.inbox_items }, Inbox::Item.orderable_columns],
    ['/exports', -> { seed_membership.exports }, MonitoringList::Export.orderable_columns],
    [
      '/monitoring_lists/:id/components',
      lambda {
        pivot_list.visible_components
      },
      Component.orderable_columns - %w[relevance]
],
    ['/monitoring_lists/:id/subscriptions', -> { pivot_list.subscriptions.visible }, Subscription.orderable_columns],
    [
      '/monitoring_lists/:id/component_requests',
      lambda {
        pivot_list.component_requests.visible
      },
      ComponentRequest.orderable_columns
],
    ['/monitoring_lists/:id/children', -> { pivot_list.visible_children }, MonitoringList.orderable_columns],
    ['/monitoring_lists/:id/parents', -> { parent_pivot_list.visible_parents }, MonitoringList.orderable_columns],
    [
      '/components/:id/monitoring_lists',
      lambda {
        pivot_component.visible_monitoring_lists
      },
      MonitoringList.orderable_columns
],
    ['/components/:id/notifications', -> { pivot_component.visible_notifications }, Notification.orderable_columns],
    [
      '/notifications/:id/components',
      lambda {
        pivot_notification.visible_components
      },
      Component.orderable_columns - %w[relevance]
],
    ['/notifications/:id/vulnerabilities', -> { pivot_notification.visible_vulnerabilities }, Notification::Vulnerability.orderable_columns]
  ]

  cases.each do |label, scope_builder, sort_keys|
    scope = scope_builder.call
    puts("\n#{label}  (#{scope.count} records)")

    sort_keys.each do |key|
      [key, "-#{key}"].each do |sort_param|
        report_case(label, sort_param, scope_builder.call.json_api_sort(sort_param), PAGE_SIZES)
      end
    end
  end

  puts("\n--- mixed directions and tampered cursors ---")
  report_case('/components', 'name,-vendor', Component.visible.json_api_sort('name,-vendor'), [7])

  sorted = Component.visible.json_api_sort('name')
  columns = Keyset::Columns.of(sorted)
  tampered = Base64.urlsafe_encode64(['vendor asc, id asc', 'x', 1].to_json, padding: false)
  begin
    Keyset::Cursor.decode(tampered, columns)
    puts('  FAIL   cursor from a different sort was accepted')
  rescue Keyset::InvalidCursor
    puts('  PASS   cursor from a different sort is rejected')
  end

  null_cursor = Base64.urlsafe_encode64(['name asc, id asc', nil, 1].to_json, padding: false)
  begin
    Keyset::Cursor.decode(null_cursor, columns)
    puts('  FAIL   cursor carrying a NULL was accepted')
  rescue Keyset::InvalidCursor
    puts('  PASS   cursor carrying a NULL is rejected')
  end

  begin
    Keyset::Cursor.decode('not base64 at all!!', columns)
    puts('  FAIL   malformed cursor was accepted')
  rescue Keyset::InvalidCursor
    puts('  PASS   malformed cursor is rejected')
  end
end
