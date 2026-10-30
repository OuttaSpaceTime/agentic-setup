#   TODO: cleanup comments later on and move into own file

MIN_MEMBERSHIPS = 20_000

Current.without_organization_and_membership_scopes do
  @org, existing = Membership.group(:organization_id).count.max_by { |_, count| count } || [nil, 0]

  if existing.to_i < MIN_MEMBERSHIPS
    seeder = DatabaseSeeder.new(
      organizations: 1,
      users: 30_000,
      memberships_per_user: 1..5,
      component_vendors: 10,
      component_names: 10,
      components: 10,
      notifications: 0,
      monitoring_list_per_org: 0,
      subscribers_per_ml: 0..0,
      components_per_ml: 0..0,
      inbox_items: 0,
      support_dropped_events: 0,
      ml_events_per_org: 0,
      notification_events_per_org: 0,
      admin_expiry_items_per_org: 0
    )
    seeder.run
    @org = seeder.org_ids.first
  end

  ActiveRecord::Base.connection.execute('ANALYZE users, memberships')
  total = Membership.where(organization_id: @org).count
  puts("org #{@org}: #{total} memberships (seeded now: #{existing.to_i < MIN_MEMBERSHIPS})\n\n")

  fixed = Membership.where(organization_id: @org)
    .joins(:user).order(users: { name: :asc }, id: :asc).limit(50)

  puts(fixed.explain(:analyze).inspect)
  puts("\n\n")

  cursor = fixed.offset(total * 3 / 4).first
  deep = fixed.where(
    'users.name > :name OR (users.name = :name AND memberships.id > :id)',
    name: cursor.user.name,
    id: cursor.id
  )

  puts(deep.explain(:analyze).inspect)
  puts("\n\n")

  naive = Membership.where(organization_id: @org)
    .includes(:user).order(users: { name: :asc }, id: :asc).limit(50)

  puts(naive.explain(:analyze).inspect)
  puts("\n\n")

  cursor_after = Membership.where(organization_id: @org).joins(:user)
    .json_api_sort_and_paginate(sort: 'user_name', page: { size: 50 })
    .links.dig(:next, :page, :after)

  puts('How our own pagination code runs for the cursor page')
  ActiveSupport::Notifications.subscribed(
    lambda { |*, p|
      puts(p[:sql]) if p[:sql].include?('ORDER BY')
    },
    'sql.active_record'
  ) do
    Membership.where(organization_id: @org).joins(:user)
      .json_api_sort_and_paginate(sort: 'user_name',
        page: {
          after: cursor_after, size: 50
        }
      )
  end
end
