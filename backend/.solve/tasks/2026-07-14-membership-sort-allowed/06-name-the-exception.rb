exc = nil
ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*a|
  exc = ActiveSupport::Notifications::Event.new(*a).payload[:exception_object]
end
membership = Current.without_organization_and_membership_scopes do
  Membership.find(ActiveRecord::FixtureSet.identify(:superuser_as_admin_in_a, :uuid))
end
token = Current.set(organization: membership.organization, membership: membership) do
  ApiToken.create!(membership: membership, name: "exc-#{Time.now.to_i}").token
end
session = ActionDispatch::Integration::Session.new(Rails.application)
session.host = 'localhost'
%w[componentRequests subscriptions].each do |resource|
  session.get(
    "/api/v2/#{resource}?sort=memberships",
    headers: { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/vnd.api+json' }
  )
  puts("#{resource}: status=#{session.response.status} exc=#{exc.class}: #{exc&.message}")
end
