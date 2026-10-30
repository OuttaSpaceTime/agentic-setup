FIXTURE = :superuser_as_admin_in_a

exception = nil
ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
  exception = ActiveSupport::Notifications::Event.new(*args).payload[:exception_object]
end

membership = Current.without_organization_and_membership_scopes do
  Membership.find(ActiveRecord::FixtureSet.identify(FIXTURE, :uuid))
end
token, ml_id = Current.set(organization: membership.organization, membership: membership) do
  [
    ApiToken.create!(membership: membership, name: "script-request-#{Time.now.to_i}").token,
    MonitoringList.joins(:components).order(:id).pick(:id)
  ]
end

session = ActionDispatch::Integration::Session.new(Rails.application)
session.host = 'localhost'

[
  "include=components&fields[components]=created_at",
  "include=components&fields[component]=createdAt",
  "include=components&fields[componentss]=createdAt",
  "include=component&fields[components]=createdAt"
].each do |query|
  exception = nil
  path = "/api/v2/monitoringLists/#{ml_id}/relationships/components?#{query}"
  session.get(path, headers: { 'Authorization' => "Bearer #{token}" }, as: :jsonapi)
  puts("\nGET #{path} -> HTTP #{session.response.status}")
  puts("exception: #{exception.class}: #{exception&.message}") if exception
  puts(session.response.body[0, 1200])
end
