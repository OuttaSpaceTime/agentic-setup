require('test_helper')
require(Rails.root.join('db/migrate/20260916091227_backfill_cached_user_fields_on_memberships.rb').to_s)

class BackfillCachedUserFieldsOnMembershipsTest < ActiveSupport::TestCase
  test('backfills cached user fields for memberships in every organization') do
    nameless_user = User.create!(email: 'nameless@example.com', name: nil)
    Membership.unscoped.first.update_columns(user_id: nameless_user.id)
    Membership.unscoped.update_all(user_name: 'stale', user_email: 'stale@example.com')

    run_migration

    memberships = Membership.unscoped

    assert_operator(memberships.map(&:organization_id).uniq.size, :>, 1)
    assert_empty(memberships.joins(:user).where.not('memberships.user_email = users.email'))
    assert_equal('', memberships.find_by(user_id: nameless_user.id).user_name)
  end

  private

  def run_migration
    BackfillCachedUserFieldsOnMemberships.new.exec_migration(ActiveRecord::Base.lease_connection, :up)
  end
end
