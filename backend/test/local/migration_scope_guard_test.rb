require('test_helper')

class MigrationScopeGuardTest < ActiveSupport::TestCase
  class BareCurrentConstant < ActiveRecord::Migration[8.1]
    def up
      Current.without_organization_and_membership_scopes { Subscription.count }
    end
  end

  def migrate(migration)
    instance = migration.new
    instance.suppress_messages { instance.exec_migration(ActiveRecord::Base.lease_connection, :up) }
  end

  def migrate_up(&up)
    migrate(Class.new(ActiveRecord::Migration[8.1]) { define_method(:up, &up) })
  end

  test('aborts a read the nil organization scope narrows to no rows') do
    error = assert_raises(MigrationScopeGuard::Violation) { migrate_up { Subscription.count } }

    assert_includes(error.message, MigrationScopeGuard::SCOPE_MESSAGE)
    assert_includes(error.message, '"subscriptions"."organization_id" IS NULL')
  end

  test('aborts an update the nil organization scope narrows to no rows') do
    error = assert_raises(MigrationScopeGuard::Violation) do
      migrate_up { Subscription.update_all(updated_at: Time.current) }
    end

    assert_includes(error.message, 'UPDATE "subscriptions"')
  end

  test('aborts a join from a plain model into an org scoped one') do
    error = assert_raises(MigrationScopeGuard::Violation) do
      migrate_up { Organization.joins(:monitoring_lists).count }
    end

    assert_includes(error.message, '"monitoring_lists"."organization_id" IS NULL')
  end

  test('accepts a query wrapped in a single organization') do
    assert_nothing_raised { migrate_up { ::Current.set(organization: Organization.first) { Subscription.count } } }
  end

  test('accepts a query wrapped in without_organization_and_membership_scopes') do
    assert_nothing_raised do
      migrate_up do
        ::Current.without_organization_and_membership_scopes { Subscription.update_all(updated_at: Time.current) }
      end
    end
  end

  test('accepts a model that neither scopes by organization nor by tlp') do
    assert_nothing_raised { migrate_up { Billing::ConsumptionPeriod.count } }
  end

  test('aborts a deliberate null organization filter because the SQL is indistinguishable from the scope') do
    assert_raises(MigrationScopeGuard::Violation) do
      migrate_up { Billing::ConsumptionPeriod.where(organization_id: nil).count }
    end
  end

  test('accepts hand written SQL because the check anchors on Arel quoted identifiers') do
    assert_nothing_raised do
      migrate_up { select_value('SELECT COUNT(*) FROM billing_consumption_periods WHERE organization_id IS NULL') }
    end
  end

  test('aborts a query the tlp scope narrows to unrestricted rows') do
    error = assert_raises(MigrationScopeGuard::Violation) { migrate_up { Component.count } }

    assert_includes(error.message, MigrationScopeGuard::TLP_MESSAGE)
    assert_includes(error.message, 'FROM "components"')
  end

  test('accepts a query that asks only for restricted rows') do
    assert_nothing_raised { migrate_up { Component.including_tlp_amber_strict.where(tlp_amber_strict: true).count } }
  end

  test('accepts a query that opts into restricted rows') do
    assert_nothing_raised { migrate_up { Component.including_tlp_amber_strict.count } }
  end

  test('aborts on Current written without the leading colons') do
    error = assert_raises(MigrationScopeGuard::Violation) { migrate(BareCurrentConstant) }

    assert_equal(MigrationScopeGuard::CBASE_MESSAGE, error.message)
  end
end
