# Fire a real request at a v2 endpoint through the full Rails stack, in-process.
# Adapt the four constants, then run bare (SolveIt task script):
#   bin/rails runner .solve/tasks/<date>-<name>/request.rb
# Debug: add `debugger` on any line, then run the line above in a terminal pane.
#   At (rdbg): p x, info, n next, s step, c continue, help. More: https://github.com/ruby/debug#debug-command-on-the-debug-console
#
# Why in-process (not curl against `bin/rails server`): this shares the runner's
# DB and secret_key_base, so the ApiToken minted below actually authenticates.
# A separate server process has a different secret and would 401 the token.

FIXTURE = :superuser_as_admin_in_a               # membership with the permissions the endpoint needs
PATH    = '/api/v2/componentRequests?sort=id'    # check config/routes.rb — paths can be camelCase (path: '...')
METHOD  = :get                                   # :get :post :patch :delete
BODY    = nil                                    # JSON:API hash for post/patch, e.g. { data: { type: '...', attributes: {} } }

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
session.host = 'localhost' # REQUIRED: dev config.hosts blocks the default www.example.com with a 403 before routing
session.public_send(METHOD, PATH, params: BODY, headers: { 'Authorization' => "Bearer #{token}" }, as: :jsonapi)

puts("#{METHOD.upcase} #{PATH} -> HTTP #{session.response.status}")
puts("exception: #{exception.class}: #{exception&.message}") if exception
puts(session.response.body[0, 1500])
