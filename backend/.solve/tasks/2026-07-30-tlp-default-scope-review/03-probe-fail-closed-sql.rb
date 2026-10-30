# bin/rails runner .solve/tasks/2026-07-30-tlp-default-scope-review/03-probe-fail-closed-sql.rb
def hides_restricted? = Component.all.to_sql.include?('tlp_amber_strict')

puts "no Current at all:      #{hides_restricted?}"
Current.set(organization: Organization.first) { puts "org set:                #{hides_restricted?}" }
Current.without_organization_and_membership_scopes { puts "cross-org bypass:       #{hides_restricted?}" }
puts "Component.new default:  #{Component.new.tlp_amber_strict.inspect}"
