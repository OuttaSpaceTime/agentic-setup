ml_id = 'fd836bbb-70cf-55fa-8a62-498d50efc502'

Current.without_organization_and_membership_scopes do
  ml = MonitoringList.find(ml_id)
  puts("name: #{ml.name}, organization: #{ml.organization.name}")
  puts("components (unscoped by org/membership): #{ml.components.count}")
end

membership = Current.without_organization_and_membership_scopes do
  Membership.find(ActiveRecord::FixtureSet.identify(:superuser_as_admin_in_a, :uuid))
end
Current.set(organization: membership.organization, membership: membership) do
  ml = MonitoringList.visible.find(ml_id)
  puts("as superuser_as_admin_in_a: components=#{ml.components.count} visible_components=#{ml.visible_components.count}")
end
