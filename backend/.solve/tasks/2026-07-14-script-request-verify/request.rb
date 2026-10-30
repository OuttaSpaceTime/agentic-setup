FIXTURE = :superuser_as_admin_in_a
PATH    = '/api/v2/componentRequests?sort=id'
METHOD  = :get
BODY    = nil

exception = nil
ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
  exception = ActiveSupport::Notifications::Event.new(*args).payload[:exception_object]
end

membership = Current.without_organization_and_membership_scopes do
  Membership.find(ActiveRecord::FixtureSet.identify(FIXTURE, :uuid))
end
token = Current.set(organization: membership.organization, membership: membership) do
  ApiToken.create!(membership: membership, name: "script-request-#{Time.now.to_i}").token
end

session = ActionDispatch::Integration::Session.new(Rails.application)
session.host = 'localhost'
session.public_send(METHOD, PATH, params: BODY, headers: { 'Authorization' => "Bearer #{token}" }, as: :jsonapi)

puts("#{METHOD.upcase} #{PATH} -> HTTP #{session.response.status}")
puts("exception: #{exception.class}: #{exception&.message}") if exception
puts(session.response.body[0, 400])
