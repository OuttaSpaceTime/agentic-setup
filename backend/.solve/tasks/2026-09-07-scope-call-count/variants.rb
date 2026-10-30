module Kernel
  def debugger(*, **) = nil
end

MEMBERSHIP_ID = '9ea22bb4-fd9d-59e8-87b8-04f86fe8a8a1'.freeze
LIST_ID = 'd9053424-dff7-442d-8759-121a53acabac'.freeze
FIELDS = 'fields%5BmonitoringLists%5D=name,active,createdAt,updatedAt,subscriptions'.freeze

VARIANTS = {
  'children  include=children + fields(subscriptions)' => "?include=children&#{FIELDS}",
  'children  fields(subscriptions) only' => "?#{FIELDS}",
  'children  include=children only' => '?include=children',
  'children  no params' => '',
  'children  include+fields, page size 1' => "?include=children&#{FIELDS}&page%5Bsize%5D=1",
  'parents   include=parents + fields(subscriptions)' => "?include=parents&#{FIELDS}"
}.freeze

$calls = []
$probing = false

MonitoringList.singleton_class.prepend(Module.new do
  def subscribed_by_with_descendants(membership)
    return super if $probing

    $calls << caller.grep(%r{vilocify-portal/app/}).first(2).map { |f| f.sub("#{Rails.root}/", '') }
    super
  end
end)

membership = Current.without_organization_and_membership_scopes { Membership.find(MEMBERSHIP_ID) }
Current.set(organization: membership.organization, membership: membership) do
  list = MonitoringList.find(LIST_ID)
  puts("list #{list.name.inspect}  children=#{list.children.count}  parents=#{list.parents.count}  subscriptions=#{list.subscriptions.count}")
  puts("children subscription counts=#{list.children.map { |c| c.subscriptions.count }}")
end

token = Current.set(organization: membership.organization, membership: membership) do
  ApiToken.create!(membership: membership, name: "variants-#{Time.now.to_i}").token
end

session = ActionDispatch::Integration::Session.new(Rails.application)
session.host = 'localhost'

VARIANTS.each do |label, query|
  rel = label.start_with?('parents') ? 'parents' : 'children'
  $calls = []
  session.get("/api/v2/monitoringLists/#{LIST_ID}/relationships/#{rel}#{query}",
              headers: { 'Authorization' => "Bearer #{token}" }, as: :jsonapi)
  puts("\n#{label}  ->  HTTP #{session.response.status}  calls=#{$calls.size}")
  $calls.map(&:first).tally.each { |frame, n| puts("    #{n}x  #{frame}") }
end
