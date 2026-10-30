organization = Current.without_organization_and_membership_scopes { Organization.find_by!(name: 'Organization A') }
user = User.find_by!(email: 'superuser@example.com')
membership = Current.without_organization_and_membership_scopes do
  Membership.find_by!(user: user, organization: organization, role: 'admin')
end

Current.set(organization: organization) do
  puts("membership id: #{membership.id}")
  puts("inbox_items_count (counter cache): #{membership.inbox_items_count}")
  puts("real Inbox::Item rows: #{Inbox::Item.where(membership: membership).count}")
end
