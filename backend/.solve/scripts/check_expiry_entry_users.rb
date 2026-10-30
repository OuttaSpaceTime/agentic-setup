# Read-back: for each MembershipExpirySummary item, show total entries vs distinct memberships.
#   bin/rails runner .solve/scripts/check_expiry_entry_users.rb
Current.without_organization_and_membership_scopes do
  Inbox::Item::MembershipExpirySummary.order(:created_at).each do |summary|
    memberships = summary.entries.map(&:membership).compact
    distinct = memberships.map(&:id).uniq.size
    puts("summary #{summary.id}: #{summary.entries.count} entries, #{distinct} distinct memberships")
    puts("  sample names: #{memberships.map { |m| m.user&.name }.tally.first(6).to_h}")
  end
end
