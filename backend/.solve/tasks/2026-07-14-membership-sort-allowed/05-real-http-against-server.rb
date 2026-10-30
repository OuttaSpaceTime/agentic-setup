require 'net/http'
membership = Current.without_organization_and_membership_scopes do
  Membership.find(ActiveRecord::FixtureSet.identify(:superuser_as_admin_in_a, :uuid))
end
token = Current.set(organization: membership.organization, membership: membership) do
  ApiToken.create!(membership: membership, name: "http-#{Time.now.to_i}").token
end
%w[component_requests subscriptions].each do |resource|
  uri = URI("http://localhost:3000/api/v2/#{resource}?sort=membership")
  req = Net::HTTP::Get.new(uri)
  req['Authorization'] = "Bearer #{token}"
  req['Accept'] = 'application/vnd.api+json'
  res = Net::HTTP.start(uri.host, uri.port) { |h| h.request(req) }
  puts("#{resource}: HTTP #{res.code} (#{res.content_type})")
  puts(res.body[0, 400])
end
