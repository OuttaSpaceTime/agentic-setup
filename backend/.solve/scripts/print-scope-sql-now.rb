# Print the SQL each filter scope generates in the CURRENT tree, and count nested SELECTs,
# to see how many subquery levels are left. Read-only.
#   RAILS_ENV=test bin/rails runner .solve/scripts/print-scope-sql-now.rb

def fixture_id(label, type = nil) = ActiveRecord::FixtureSet.identify(label, type)

def report(label, relation)
  sql = relation.to_sql
  nested = sql.scan(/SELECT/i).size - 1
  puts("\n#{label}  (nested SELECTs: #{nested})")
  puts(sql.gsub(/ (AND|WHERE|IN \(SELECT)/) { "\n    #{Regexp.last_match(1)}" })
end

membership = Current.without_organization_and_membership_scopes do
  Membership.unscoped.find(fixture_id(:superuser_as_admin_in_a, :uuid))
end

Current.set_from_membership(membership) do
  component_ids = [fixture_id(:one), fixture_id(:insecure_component)]
  notification_ids = [fixture_id(:eol_notification)]
  ml_ids = [fixture_id(:parent, :uuid)]

  report('MonitoringList.by_components(literal ids)', MonitoringList.unscoped.by_components(component_ids))
  report('MonitoringList.by_notifications(ids)', MonitoringList.unscoped.by_notifications(notification_ids))
  report('Notification.by_components(literal ids)', Notification.unscoped.by_components(component_ids))
  report('Notification.by_monitoring_lists(ids)', Notification.unscoped.by_monitoring_lists(ml_ids))
end
