# Clears entries on superuser_as_admin_in_a's MembershipExpirySummary items so the seed rebuilds
# them with distinct filler memberships. Memberships survive; only the join rows are destroyed.
#   bin/rails runner .solve/scripts/reset_expiry_summary_entries.rb
Current.without_organization_and_membership_scopes do
  organization = Organization.find_by!(name: 'Organization A')
  user = User.find_by!(email: 'superuser@example.com')
  recipient = Membership.find_by!(user: user, organization: organization, role: 'admin')
  recipient.inbox_items.where(itemable_type: 'Inbox::Item::MembershipExpirySummary').find_each do |item|
    count = item.itemable.entries.destroy_all.size
    puts("cleared #{count} entries from Inbox::Item #{item.id}")
  end
end
