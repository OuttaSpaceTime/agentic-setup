# Does joins(:visible_components) + DISTINCT survive the real request pipeline —
# json_api_filter -> json_api_sort_and_paginate (cursor) — for every orderable column,
# for a privileged org, and composed with full_text_search? Rolled back — non-destructive.
#   bin/rails runner .solve/scripts/verify-join-distinct-through-paginator.rb

def page_ids(relation, sort:)
  result = relation.json_api_sort_and_paginate(sort: sort, page: { size: 5 })
  records = result.respond_to?(:records) ? result.records : Array(result).flatten.select { |r| r.respond_to?(:id) }
  [:ok, records.map(&:id)]
rescue StandardError => e
  [:raised, "#{e.class}: #{e.message[0, 120]}"]
end

def compare(label, baseline, variant, sorts)
  sorts.each do |sort|
    a_status, a = page_ids(baseline, sort: sort)
    b_status, b = page_ids(variant, sort: sort)

    verdict =
      if a_status == :raised || b_status == :raised
        "SKIPPED (baseline=#{a_status} variant=#{b_status}) #{a_status == :raised ? a : b}"
      elsif a != b
        "DIFFERENT\n      baseline=#{a.inspect}\n      variant =#{b.inspect}"
      elsif a.empty?
        'EMPTY — proves nothing'
      else
        "SAME (#{a.size} rows)"
      end

    puts("  #{label} sort=#{sort.ljust(14)} #{verdict}")
  end
end

Current.without_organization_and_membership_scopes do
  ActiveRecord::Base.transaction do
    DatabaseSeeder.new(
      organizations: 2, users: 100, memberships_per_user: 1..1,
      component_vendors: 50, component_names: 100, components: 3_000,
      notifications: 600, monitoring_list_per_org: 40,
      subscribers_per_ml: 1..5, components_per_ml: 20..100,
      inbox_items: 0, support_dropped_events: 0, ml_events_per_org: 0,
      notification_events_per_org: 0, notification_revisions_per_event: 0..0,
      notification_subscribers_per_event: 0..0
    ).run

    Component.unscoped.where(id: Component.unscoped.order('random()').limit(900).select(:id))
      .update_all(tlp_amber_strict: true)

    org = Organization.unscoped.joins(:monitoring_lists).group('organizations.id')
      .order(Arel.sql('COUNT(monitoring_lists.id) DESC')).limit(1).first
    Organization.unscoped.where(id: org.id).update_all(can_see_tlp_amber_strict: true)
    membership = Membership.unscoped.where(organization_id: org.id)
      .find { |m| m.permissions.include?('read:components') }

    Current.set_from_membership(membership) do
      puts("read:tlp_amber_strict=#{Current.permissions.include?('read:tlp_amber_strict')}")
      notification_ids = NotificationComponentAssignment.unscoped.limit(50).pluck(:notification_id).uniq
      ml_ids = MonitoringList.unscoped.where(organization_id: org.id).limit(20).pluck(:id)

      puts("\n== MonitoringList, filter[notifications.id][any] ==")
      compare(
        'ML',
        MonitoringList.visible.json_api_filter('notifications.id' => { 'any' => notification_ids.join(',') }),
        MonitoringList.visible.joins(visible_components: :notification_component_assignments)
          .where(notification_component_assignments: { notification_id: notification_ids }).distinct,
        MonitoringList.orderable_columns.flat_map { |c| [c, "-#{c}"] }
      )

      puts("\n== Notification, filter[monitoringLists.id][any] ==")
      base = Notification.visible.json_api_filter('monitoring_lists.id' => { 'any' => ml_ids.join(',') })
      variant = Notification.visible.joins(visible_components: :monitoring_lists_components)
        .where(monitoring_lists_components: { monitoring_list_id: ml_ids }).distinct
      compare('N', base, variant, Notification.orderable_columns.flat_map { |c| [c, "-#{c}"] })

      puts("\n== Notification, same filter composed with full_text_search ==")
      compare('N+search', base.full_text_search('a'), variant.full_text_search('a'), %w[id -id prio])

      puts("\n== cursor paging: walk 3 pages, baseline vs variant ==")
      puts("  Notification.cursor_paginatable_columns=#{Notification.cursor_paginatable_columns.inspect}")
      probe = variant.json_api_sort_and_paginate(sort: 'id', page: { size: 5 })
      puts("  result class=#{probe.class} methods=#{(probe.public_methods(false) - Object.methods).sort.inspect}")
      puts("  links=#{probe.try(:links).inspect}")

      %w[id created_at].each do |sort|
        [['baseline', base], ['variant', variant]].each do |name, rel|
          cursor = nil
          pages = 4.times.map do
            page = { size: 5 }
            page[:after] = cursor if cursor
            result = rel.json_api_sort_and_paginate(sort: sort, page: page)
            cursor = result.links.dig(:next, :page, :after)
            [result.to_a.map(&:id), cursor.nil?]
          end
          ids = pages.flat_map(&:first)
          puts("  #{name.ljust(9)} sort=#{sort.ljust(11)} page_sizes=#{pages.map { |p| p.first.size }.inspect} " \
               "total=#{ids.size} unique=#{ids.uniq.size}")
        end
      end
    end

    raise(ActiveRecord::Rollback)
  end
end
