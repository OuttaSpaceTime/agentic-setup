# Fires real requests at the paginated endpoints to see what the full stack does with the sort and
# page[after] edge cases the seeded data exposes.
#
#   bin/rails runner .solve/scripts/check_sort_requests.rb

exception = nil
ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
  exception = ActiveSupport::Notifications::Event.new(*args).payload[:exception_object]
end

membership = Current.without_organization_and_membership_scopes do
  Membership.find(ActiveRecord::FixtureSet.identify(:superuser_as_admin_in_a, :uuid))
end
token = Current.set(organization: membership.organization, membership: membership) do
  ApiToken.where('name LIKE ?', 'check-sort-requests%').destroy_all
  ApiToken.create!(membership: membership, name: "check-sort-requests-#{Time.now.to_i}").token
end

session = ActionDispatch::Integration::Session.new(Rails.application)
session.host = 'localhost'

def get(session, token, path)
  session.get(path, headers: { 'Authorization' => "Bearer #{token}" }, as: :jsonapi)
  [session.response.status, session.response.body]
end

def show(label, status, body, exception)
  puts(format('%-58s HTTP %s', label, status))
  puts("  exception: #{exception.class}: #{exception.message.lines.first.strip}") if exception
  parsed = begin
    JSON.parse(body)
  rescue StandardError
    nil
  end
  if parsed&.key?('errors')
    puts("  error: #{parsed['errors'].first.slice('title', 'detail', 'source')}")
  elsif parsed&.key?('data')
    puts("  records: #{parsed['data'].size}  links: #{parsed['links']&.keys.inspect}")
    puts("  first id: #{parsed['data'].first&.dig('id')}")
  end
end

paths = [
  '/api/v2/components?sort=name&page[size]=5',
  '/api/v2/components?sort=-endOfLifeOn&page[size]=5',
  '/api/v2/components?sort=deactivatedAt&page[size]=5',
  '/api/v2/components?sort=name,-vendor&page[size]=5',
  '/api/v2/components?sort=relevance&page[size]=5',
  '/api/v2/components?filter[search][is]=Seed&sort=-relevance&page[size]=5',
  '/api/v2/memberships?sort=expiresAt&page[size]=5',
  '/api/v2/memberships?sort=userName&page[size]=5',
  '/api/v2/componentRequests?sort=vendor&page[size]=5'
]

paths.each do |path|
  exception = nil
  status, body = get(session, token, path)
  show(path, status, body, exception)
end

puts("\n--- page[after] handling ---")
_status, body = get(session, token, '/api/v2/components?sort=name&page[size]=5')
next_link = JSON.parse(body).dig('links', 'next')
cursor = next_link && Rack::Utils.parse_nested_query(URI.parse(next_link).query).dig('page', 'after')
puts("cursor from links.next: #{cursor.inspect}")

[
  ['valid cursor', cursor],
  ['cursor from a different sort', Base64.urlsafe_encode64(['vendor asc, id asc', 'Adobe', 1].to_json, padding: false)],
  ['cursor carrying a NULL', Base64.urlsafe_encode64(['name asc, id asc', nil, 1].to_json, padding: false)],
  ['malformed cursor', 'not-base64-at-all!!']
].each do |label, value|
  exception = nil
  status, body = get(session, token, "/api/v2/components?sort=name&page[size]=5&page[after]=#{CGI.escape(value.to_s)}")
  show("  #{label}", status, body, exception)
end
