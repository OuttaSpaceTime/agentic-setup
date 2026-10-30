# Proves the inbox entry snapshot backfills (published_at on notification revisions,
# expires_at on expiry summary entries) against edge cases the fixtures cannot express:
# - a revision whose notification exists -> gets notifications.created_at
# - an orphaned revision (notification_id NULL, i.e. since-deleted notification) -> stays NULL
# - an entry whose membership has an expires_at -> gets it
# - an entry whose membership has no expires_at -> stays NULL
# - an orphaned entry (membership_id NULL, i.e. since-deleted membership) -> stays NULL
# Non-destructive: reverses the four migrations inside a transaction, seeds old-shape
# rows, runs the real migrations, rolls back. The FKs are ON DELETE SET NULL, so the
# "deleted source" states are the NULL foreign keys, not dangling ids.
#   RAILS_ENV=test bin/rails runner .solve/scripts/prove_inbox_entry_snapshot_backfills.rb
migrations = Rails.root.join('db/migrate')
require(migrations.join('20261016113804_add_published_at_to_inbox_item_monitoring_list_notification_revisions'))
require(migrations.join('20261016113806_backfill_published_at_on_inbox_item_monitoring_list_notification_revisions'))
require(migrations.join('20261016113809_add_expires_at_to_inbox_item_membership_expiry_summary_entries'))
require(migrations.join('20261016113812_backfill_expires_at_on_inbox_item_membership_expiry_summary_entries'))

Current.without_organization_and_membership_scopes do
  ActiveRecord::Base.transaction do
    conn = ActiveRecord::Base.connection

    # The columns exist in the live DB, so reverse in order (backfill down, then column down)
    ActiveRecord::Migration.suppress_messages do
      BackfillExpiresAtOnInboxItemMembershipExpirySummaryEntries.new.down
      AddExpiresAtToInboxItemMembershipExpirySummaryEntries.new.down
      BackfillPublishedAtOnInboxItemMonitoringListNotificationRevisions.new.down
      AddPublishedAtToInboxItemMonitoringListNotificationRevisions.new.down
    end

    membership_cols = 'SELECT id, user_email FROM memberships'
    notification = conn.select_one('SELECT id, created_at FROM notifications ORDER BY id LIMIT 1')
    with_expiry = conn.select_one(
      "#{membership_cols} WHERE expires_at IS NOT NULL ORDER BY id LIMIT 1"
    )
    with_expiry ||= conn.select_one("#{membership_cols} ORDER BY id LIMIT 1")
    exclude = "id <> #{conn.quote(with_expiry['id'])}"
    no_expiry = conn.select_one("#{membership_cols} WHERE #{exclude} AND expires_at IS NULL ORDER BY id LIMIT 1")
    no_expiry ||= conn.select_one("#{membership_cols} WHERE #{exclude} ORDER BY id LIMIT 1")
    summary_id = conn.select_value('SELECT id FROM inbox_item_membership_expiry_summaries ORDER BY id LIMIT 1')

    # Whole seconds so the DB round-trip at microsecond precision is exact
    expiring_at = 2.weeks.from_now.change(usec: 0)
    with_expiry_sql_id = conn.quote(with_expiry['id'])
    conn.update("UPDATE memberships SET expires_at = #{conn.quote(expiring_at)} WHERE id = #{with_expiry_sql_id}")
    seeded_expiry_at = conn.select_value("SELECT expires_at FROM memberships WHERE id = #{with_expiry_sql_id}")

    now = Time.current.change(usec: 0)
    seed_revision = lambda do |notification_id_sql|
      conn.select_value(
        'INSERT INTO inbox_item_monitoring_list_notification_revisions ' \
          '(notification_id, version_range, history_summary, created_at, updated_at) ' \
          "VALUES (#{notification_id_sql}, '[4,4]', NULL, #{conn.quote(now)}, #{conn.quote(now)}) RETURNING id"
      )
    end
    seed_entry = lambda do |membership_id_sql|
      now_sql = conn.quote(now)
      conn.select_value(
        'INSERT INTO inbox_item_membership_expiry_summary_entries ' \
          '(expiry_summary_id, membership_id, created_at, updated_at) ' \
          "VALUES (#{conn.quote(summary_id)}, #{membership_id_sql}, #{now_sql}, #{now_sql}) RETURNING id"
      )
    end

    rev_existing = seed_revision.call(notification['id'].to_s)
    rev_orphan = seed_revision.call('NULL')
    entry_with_expiry = seed_entry.call(conn.quote(with_expiry['id']))
    entry_no_expiry = seed_entry.call(conn.quote(no_expiry['id']))
    entry_orphan = seed_entry.call('NULL')

    ActiveRecord::Migration.suppress_messages do
      AddPublishedAtToInboxItemMonitoringListNotificationRevisions.new.up
      BackfillPublishedAtOnInboxItemMonitoringListNotificationRevisions.new.up
      AddExpiresAtToInboxItemMembershipExpirySummaryEntries.new.up
      BackfillExpiresAtOnInboxItemMembershipExpirySummaryEntries.new.up
    end

    puts("notification: #{notification['id']} (created_at #{notification['created_at'].inspect})")
    puts("membership with expires_at: #{with_expiry['id']} (#{with_expiry['user_email']})")
    puts("membership without expires_at: #{no_expiry['id']} (#{no_expiry['user_email']})")
    puts('orphan rows use NULL foreign keys, per ON DELETE SET NULL')

    check = lambda do |sql, label, expected_at|
      got = conn.select_value(sql)
      puts("#{got == expected_at ? 'PASS' : 'FAIL'} #{label} got=#{got.inspect} expected=#{expected_at.inspect}")
    end

    check.call(
      "SELECT published_at FROM inbox_item_monitoring_list_notification_revisions WHERE id = #{rev_existing}",
      "revision of existing notification (#{rev_existing})",
      notification['created_at']
    )
    check.call(
      "SELECT published_at FROM inbox_item_monitoring_list_notification_revisions WHERE id = #{rev_orphan}",
      "orphan revision, notification_id NULL (#{rev_orphan})",
      nil
    )
    check.call(
      "SELECT expires_at FROM inbox_item_membership_expiry_summary_entries WHERE id = #{conn.quote(entry_with_expiry)}",
      "entry whose membership has expires_at (#{entry_with_expiry})",
      seeded_expiry_at
    )
    check.call(
      "SELECT expires_at FROM inbox_item_membership_expiry_summary_entries WHERE id = #{conn.quote(entry_no_expiry)}",
      "entry whose membership has no expires_at (#{entry_no_expiry})",
      nil
    )
    check.call(
      "SELECT expires_at FROM inbox_item_membership_expiry_summary_entries WHERE id = #{conn.quote(entry_orphan)}",
      "orphan entry, membership_id NULL (#{entry_orphan})",
      nil
    )

    raise(ActiveRecord::Rollback)
  end
end
