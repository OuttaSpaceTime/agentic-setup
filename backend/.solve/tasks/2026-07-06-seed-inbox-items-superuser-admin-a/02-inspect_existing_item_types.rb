organization = Current.without_organization_and_membership_scopes { Organization.find_by!(name: 'Organization A') }
user = User.find_by!(email: 'superuser@example.com')
membership = Current.without_organization_and_membership_scopes do
  Membership.find_by!(user: user, organization: organization, role: 'admin')
end

Current.set(organization: organization) do
  puts(Inbox::Item.where(membership: membership).group(:item_type_cache).count)
end
