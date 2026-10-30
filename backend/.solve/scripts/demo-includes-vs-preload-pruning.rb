# Why a join-based by_components forces includable to use preload:
# with `includes`, a WHERE on the included table promotes it to eager_load (one LEFT OUTER JOIN),
# and the association is then populated from the FILTERED rows. `preload` cannot be pruned.
#   RAILS_ENV=test bin/rails runner .solve/scripts/demo-includes-vs-preload-pruning.rb

def fixture_id(label, type = nil) = ActiveRecord::FixtureSet.identify(label, type)

def show(label, relation)
  queries = []
  sub = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
    queries << payload[:sql] if payload[:name] != 'SCHEMA' && payload[:sql] =~ /SELECT/
  end
  records = relation.to_a
  puts("\n#{label}")
  puts("  queries fired: #{queries.size}")
  queries.each { |q| puts("    #{q.gsub(/\s+/, ' ')[0, 150]}…") }
  records.each do |ml|
    puts("  #{ml.name.ljust(16)} visible_components=#{ml.visible_components.map(&:id).sort.inspect}")
  end
ensure
  ActiveSupport::Notifications.unsubscribe(sub)
end

membership = Current.without_organization_and_membership_scopes do
  Membership.unscoped.find(fixture_id(:superuser_as_admin_in_a, :uuid))
end

Current.set_from_membership(membership) do
  filtered_component = fixture_id(:one)

  puts("filtering by component #{filtered_component} (components(:one))")
  puts('truth: `active` holds [one, insecure_component], `two_subscribers` holds [one]')

  join_filter = MonitoringList.visible
    .joins(:visible_components)
    .where(components: { id: [filtered_component] })
    .distinct

  show('A) join filter + includes(:visible_components)   <- what `includable` does today',
       join_filter.includes(:visible_components))

  show('B) join filter + preload(:visible_components)', join_filter.preload(:visible_components))

  subselect_filter = MonitoringList.visible.where(
    id: MonitoringListsComponent
      .where(component: Component.visible.where(id: [filtered_component]))
      .select(:monitoring_list_id)
  )

  show('C) subselect filter + includes(:visible_components)  <- current branch behaviour',
       subselect_filter.includes(:visible_components))
end
