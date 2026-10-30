membership = Current.without_organization_and_membership_scopes do
  Membership.find(ActiveRecord::FixtureSet.identify(:superuser_as_admin_in_a, :uuid))
end
token = Current.set(organization: membership.organization, membership: membership) do
  ApiToken.create!(membership: membership, name: "sort-probe-#{Time.now.to_i}").token
end

session = ActionDispatch::Integration::Session.new(Rails.application)
%w[component_requests subscriptions].each do |resource|
  session.get(
    "/api/v2/#{resource}?sort=membership",
    headers: { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/vnd.api+json' }
  )
  puts("GET /api/v2/#{resource}?sort=membership -> HTTP #{session.response.status}")
  puts(session.response.body[0, 300])
  puts('---')
end
