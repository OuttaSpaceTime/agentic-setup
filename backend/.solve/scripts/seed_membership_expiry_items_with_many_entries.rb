# Idempotent dev seed: gives superuser_as_admin_in_a (Organization A) 3 membership_expiry_summary
# inbox items, each covering every case from vilocifyInboxMembershipExpiryEntry (every role, every
# invitation state, no_expiration/expiring/expired status, a few deleted memberships) plus filler
# entries so each item spans several pages at the default page size of 20. The three items carry
# different entry counts and per-item-labelled memberships so they are visibly distinct, not clones.
#   bin/rails runner .solve/scripts/seed_membership_expiry_items_with_many_entries.rb
#   DRY_RUN=1 bin/rails runner .solve/scripts/seed_membership_expiry_items_with_many_entries.rb

ITEM_ENTRY_COUNTS = [45, 60, 90].freeze

ROLES = %w[admin user user_manager security_officer].freeze
INVITATION_STATES_WITHOUT_ACCEPTED = %w[pending failed invited].freeze
DELETED_ENTRY_COUNT = 3

def ensure_membership_limit(organization, headroom)
  period = organization.current_consumption_period ||
    organization.consumption_periods.create!(period: Date.current..1.year.from_now.to_date)
  required_credit = organization.active_memberships.count + headroom
  return if period.membership_order_count >= required_credit

  period.orders.create!(name: 'Individual', membership_request_credit: required_credit)
end

def find_or_create_entry_membership(organization, email:, name:, role:, invitation_state:, expires_at:)
  user = User.find_or_create_by!(email: email) { |u| u.name = name }
  Membership.find_or_create_by!(user: user, organization: organization, role: role) do |m|
    m.invitation_state = invitation_state
    m.expires_at = expires_at
  end
end

def seed_edge_case_entries(summary, organization, label)
  slug = label.downcase.tr(' ', '_')
  expiring_at = 10.days.from_now

  ROLES.each do |role|
    membership = find_or_create_entry_membership(
      organization,
      email: "#{slug}_#{role}@example.com",
      name: "#{label} #{role.titleize}",
      role: role,
      invitation_state: 'accepted',
      expires_at: expiring_at
    )
    summary.entries.create!(membership: membership)
  end

  INVITATION_STATES_WITHOUT_ACCEPTED.each do |invitation_state|
    membership = find_or_create_entry_membership(
      organization,
      email: "#{slug}_#{invitation_state}@example.com",
      name: "#{label} #{invitation_state.titleize}",
      role: 'user',
      invitation_state: invitation_state,
      expires_at: expiring_at
    )
    summary.entries.create!(membership: membership)
  end

  # No expiration: expiresAt is omitted (null) and status is no_expiration.
  no_expiration = find_or_create_entry_membership(
    organization,
    email: "#{slug}_no_expiration@example.com",
    name: "#{label} No Expiration",
    role: 'user',
    invitation_state: 'accepted',
    expires_at: nil
  )
  summary.entries.create!(membership: no_expiration)

  # Already expired: validation forbids a past expires_at on create, so backdate after the fact.
  expired = find_or_create_entry_membership(
    organization,
    email: "#{slug}_expired@example.com",
    name: "#{label} Expired",
    role: 'user',
    invitation_state: 'accepted',
    expires_at: expiring_at
  )
  expired.update_column(:expires_at, 2.hours.ago)
  summary.entries.create!(membership: expired)

  # Deleted memberships: the entry survives with membership_id nullified, rendered as deleted: true.
  DELETED_ENTRY_COUNT.times do |i|
    membership = find_or_create_entry_membership(
      organization,
      email: "#{slug}_deleted_#{i + 1}@example.com",
      name: "#{label} Deleted #{i + 1}",
      role: 'user',
      invitation_state: 'accepted',
      expires_at: expiring_at
    )
    summary.entries.create!(membership: membership)
    membership.destroy!
  end
end

Current.without_organization_and_membership_scopes do
  ActiveRecord::Base.transaction do
    organization = Organization.find_or_create_by!(name: 'Organization A')
    ensure_membership_limit(organization, ITEM_ENTRY_COUNTS.sum + 25)

    user = User.find_or_create_by!(email: 'superuser@example.com') { |u| u.name = 'Super User' }
    recipient = Membership.find_or_create_by!(user: user, organization: organization, role: 'admin') do |m|
      m.invitation_state = 'accepted'
    end

    ITEM_ENTRY_COUNTS.each_with_index do |target_count, index|
      label = "Expiry #{index + 1}"
      existing_item = recipient.inbox_items
        .where(itemable_type: 'Inbox::Item::MembershipExpirySummary')
        .order(:created_at)[index]
      summary = existing_item&.itemable ||
        Inbox::Item::MembershipExpirySummary.create!(organization: organization, remind_until: 3.weeks.from_now)
      inbox_item = summary.item ||
        summary.create_item!(membership: recipient, organization: organization, read: false)

      if summary.entries.count >= target_count
        puts("#{label}: Inbox::Item #{inbox_item.id} already has #{summary.entries.count} entries")
        next
      end

      seed_edge_case_entries(summary, organization, label)

      slug = label.downcase.tr(' ', '_')
      expires_at = 10.days.from_now
      (target_count - summary.entries.count).times do |i|
        filler = find_or_create_entry_membership(
          organization,
          email: "#{slug}_filler_#{i + 1}@example.com",
          name: "#{label} Filler #{i + 1}",
          role: 'user',
          invitation_state: 'accepted',
          expires_at: expires_at
        )
        summary.entries.create!(membership: filler)
      end

      puts("#{label}: Inbox::Item #{inbox_item.id} now has #{summary.entries.count} entries")
    end

    raise(ActiveRecord::Rollback) if ENV['DRY_RUN']
  end
end
