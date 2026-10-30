membership = Current.without_organization_and_membership_scopes do
  Membership.find(ActiveRecord::FixtureSet.identify(:superuser_as_admin_in_a, :uuid))
end
token = Current.set(organization: membership.organization, membership: membership) do
  ApiToken.create!(membership: membership, name: "req-#{Time.now.to_i}").token
end
log = File.open(File.join(__dir__, 'response.log'), 'w')
session = ActionDispatch::Integration::Session.new(Rails.application)
%w[componentRequests subscriptions].each do |resource|
  session.get(
    "/api/v2/#{resource}?sort=membership",
    headers: { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/vnd.api+json' }
  )
  exception = session.request.env['action_dispatch.exception']
  log.puts("=== #{resource}: HTTP #{session.response.status} ===")
  log.puts("exception: #{exception.class}: #{exception&.message}")
  log.puts((exception&.backtrace || []).grep(%r{vilocify-portal/app}).first(5).join("\n"))
end
log.close
puts(File.read(File.join(__dir__, 'response.log')))
