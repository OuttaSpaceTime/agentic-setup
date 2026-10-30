module Kernel
  def debugger(*, **) = nil
end

MEMBERSHIP_ID = '9ea22bb4-fd9d-59e8-87b8-04f86fe8a8a1'.freeze
LIST_ID = 'd9053424-dff7-442d-8759-121a53acabac'.freeze

PATHS = [
  '/api/v2/sessions/current',
  "/api/v2/subscriptions?filter%5Bmembership.id%5D%5Beq%5D=#{MEMBERSHIP_ID}&filter%5BmonitoringList.id%5D%5Beq%5D=#{LIST_ID}",
  "/api/v2/monitoringLists/#{LIST_ID}?fields%5BmonitoringLists%5D=name,comment,active,createdAt,updatedAt,components,children",
  '/api/v2/userSettings/',
  '/api/v2/membershipSettings/',
  "/api/v2/monitoringLists/#{LIST_ID}/relationships/parents?include=parents&fields%5BmonitoringLists%5D=name,active,createdAt,updatedAt,subscriptions",
  "/api/v2/monitoringLists/#{LIST_ID}/relationships/children?include=children&fields%5BmonitoringLists%5D=name,active,createdAt,updatedAt,subscriptions"
].freeze

$calls = []
$queries = 0
$empty = 0
$probing = false
$empty_frames = []

MonitoringList.singleton_class.prepend(Module.new do
  def subscribed_by_with_descendants(membership)
    return super if $probing

    frames = caller.grep(%r{vilocify-portal/(app|lib)/}).first(4).map { |f| f.sub("#{Rails.root}/", '') }
    $calls << frames
    begin
      $probing = true
      inner = where(id: MonitoringList.includes(:subscriptions).where(subscriptions: { membership: membership }))
      if inner.empty?
        $empty += 1
        $empty_frames << frames
      end
    ensure
      $probing = false
    end
    super
  end
end)

ActiveSupport::Notifications.subscribe('sql.active_record') { $queries += 1 }

membership = Current.without_organization_and_membership_scopes { Membership.find(MEMBERSHIP_ID) }
puts("membership role=#{membership.role}")
puts("permissions=#{Current.set(organization: membership.organization, membership: membership) { Current.permissions.grep(/monitoring_lists|subscriptions/) }}")

token = Current.set(organization: membership.organization, membership: membership) do
  ApiToken.create!(membership: membership, name: "scope-count-#{Time.now.to_i}").token
end

session = ActionDispatch::Integration::Session.new(Rails.application)
session.host = 'localhost'

PATHS.each do |path|
  $calls = []
  $queries = 0
  $empty = 0
  $empty_frames = []
  session.get(path, headers: { 'Authorization' => "Bearer #{token}" }, as: :jsonapi)
  puts("\n=== HTTP #{session.response.status}  scope_calls=#{$calls.size}  empty(=debugger stops)=#{$empty}  sql=#{$queries}  #{path[0, 90]}")
  $calls.map(&:first).tally.each { |frame, n| puts("    #{n}x  #{frame}") }
end

puts("\n=== the EMPTY call(s) of the last request ===")
$empty_frames.each { |frames| puts(frames.map { |f| "    #{f}" }.join("\n")) }
puts("\n=== every call of the last request (children), frames 1-3 ===")
$calls.each_with_index do |frames, i|
  puts("  ##{i + 1} #{frames[0]}")
  frames[1, 3].to_a.each { |f| puts("        <- #{f}") }
end
