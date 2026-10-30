require('test_helper')
require(Rails.root.join('db/migrate/20260702155544_backfill_item_type_cache.rb').to_s)

class BackfillItemTypeCacheTest < ActiveSupport::TestCase
  class Corrected < ActiveRecord::Migration[8.1]
    def up
      ::Current.without_organization_and_membership_scopes do
        Inbox::Item.find_each { it.update_column(:item_type_cache, it.item_type) }
      end
    end
  end

  def migrate(migration)
    instance = migration.new
    instance.suppress_messages { instance.exec_migration(ActiveRecord::Base.lease_connection, :up) }
  end

  test('the shipped migration leaks the OrgScoped default scope through item.membership') do
    assert_raises(MigrationScopeGuard::Violation) { migrate(BackfillItemTypeCache) }
  end

  test('backfills item_type_cache for items across every organization') do
    Inbox::Item.unscoped.update_all(item_type_cache: nil)

    migrate(Corrected)

    items = Inbox::Item.unscoped

    assert_operator(items.map(&:organization_id).uniq.size, :>, 1)
    assert_empty(items.where(item_type_cache: nil))
  end
end
