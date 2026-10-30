log = File.open(File.join(__dir__, 'findings.log'), 'w')
membership = Current.without_organization_and_membership_scopes do
  Membership.find(ActiveRecord::FixtureSet.identify(:superuser_as_admin_in_a, :uuid))
end
token = Current.set(organization: membership.organization, membership: membership) do
  ApiToken.create!(membership: membership, name: "diag-#{Time.now.to_i}").token
end
Current.set_from_api_token(ApiToken.authenticate(token))
log.puts("membership class: #{Current.membership.class}")
log.puts("role: #{Current.membership.try(:role)}")
log.puts("perms read:org:subscriptions? #{Current.permissions.include?('read:org:subscriptions')}")
log.puts("Subscription.visible null_relation? #{Subscription.visible.null_relation?}")
log.puts("ComponentRequest.visible null_relation? #{ComponentRequest.visible.null_relation?}")
log.close
puts(File.read(File.join(__dir__, 'findings.log')))
