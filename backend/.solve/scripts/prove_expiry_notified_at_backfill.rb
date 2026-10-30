# Proves the AddExpiryNotifiedAtToMemberships backfill: expiry_notified_at gets
# MAX(items.created_at) only for summary entries created AFTER the membership's expires_at.
# Non-destructive: seeds edge cases, reverses + re-runs the real migration, rolls back.
#   RAILS_ENV=test bin/rails runner .solve/scripts/prove_expiry_notified_at_backfill.rb
require(Rails.root.join('db/migrate/20260716091313_add_expiry_notified_at_to_memberships'))

def summary_with_entry(membership, created_at)
  summary = Inbox::Item::Membership::ExpirySummary.create!(
    organization: membership.organization, remind_until: 3.weeks.from_now
  )
  summary.entries.create!(membership: membership)
  summary.update_column(:created_at, created_at)
end

Current.without_organization_and_membership_scopes do
  ActiveRecord::Base.transaction do
    a, b, c, d, e = Membership.order(:id).limit(5).to_a
    ids = [a, b, c, d, e].map(&:id)
    Inbox::Item::Membership::ExpirySummary::Entry.where(membership_id: ids).delete_all
    reported_at_a = 5.days.ago.change(usec: 0)
    reported_at_b_later = 3.days.ago.change(usec: 0)

    a.update_column(:expires_at, 10.days.ago)
    summary_with_entry(a, reported_at_a)
    b.update_column(:expires_at, 10.days.ago)
    summary_with_entry(b, 7.days.ago)
    summary_with_entry(b, reported_at_b_later)
    c.update_column(:expires_at, 10.days.ago)
    summary_with_entry(c, 15.days.ago)
    d.update_column(:expires_at, 10.days.ago)
    e.update_column(:expires_at, 10.days.from_now)
    summary_with_entry(e, Time.current)

    ActiveRecord::Migration.suppress_messages do
      AddExpiryNotifiedAtToMemberships.new.down
      AddExpiryNotifiedAtToMemberships.new.up
    end

    Membership.reset_column_information

    expected_notified_at = { a => reported_at_a, b => reported_at_b_later, c => nil, d => nil, e => nil }
    expected_notified_at.each do |membership, expected_at|
      actual_at = membership.reload.expiry_notified_at
      matches = actual_at == expected_at
      puts("#{matches ? 'PASS' : 'FAIL'} #{membership.id} got=#{actual_at.inspect} expected=#{expected_at.inspect}")
    end
    raise(ActiveRecord::Rollback)
  end
end
