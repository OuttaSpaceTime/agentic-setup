# Does a subselect filter cause N+1? Count the queries for the filter alone, then for
# serializing each notification's components with and without `includable`. Read-only.
#   RAILS_ENV=test bin/rails runner .solve/scripts/demo-filter-query-counts.rb

def count_queries(label)
  queries = []
  sub = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
    next if payload[:name] == 'SCHEMA' || payload[:sql] =~ /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i

    queries << payload[:sql].gsub(/\s+/, ' ')
  end
  yield
  puts("\n#{label}: #{queries.size} quer#{queries.size == 1 ? 'y' : 'ies'}")
  queries.each_with_index { |q, i| puts("  #{i + 1}. #{q[0, 120]}…") }
ensure
  ActiveSupport::Notifications.unsubscribe(sub)
end

membership = Current.without_organization_and_membership_scopes do
  Membership.unscoped.find(ActiveRecord::FixtureSet.identify(:superuser_as_admin_in_a, :uuid))
end

Current.set_from_membership(membership) do
  component_ids = Component.visible.limit(20).pluck(:id)

  count_queries('A) filter scope, just loading the notifications') do
    Notification.visible.by_components(component_ids).to_a
  end

  records = nil
  count_queries('B) filter + touching visible_components per record, NO preload') do
    records = Notification.visible.by_components(component_ids).to_a
    records.each { |n| n.visible_components.map(&:id) }
  end
  puts("   (#{records.size} notifications loaded)")

  count_queries('C) filter + .includable (preload)') do
    Notification.visible.by_components(component_ids).includable.to_a.each do |n|
      n.visible_components.map(&:id)
    end
  end
end
