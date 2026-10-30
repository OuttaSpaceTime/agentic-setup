TARGET_REVISIONS = 45
DELETED_MEMBERSHIP_ID = '00000000-0000-0000-0000-000000000000'.freeze

org = Current.without_organization_and_membership_scopes do
  Organization.find_by!(name: 'Organization A')
end

superuser = User.find_by!(email: 'superuser@example.com')

membership = Current.without_organization_and_membership_scopes do
  Membership.find_by!(organization: org, role: 'admin', user: superuser)
end

ActiveRecord::Base.transaction do
  Current.set(organization: org) do
    notifications = Notification.order(:id).limit(10).to_a
    monitoring_lists = MonitoringList.order(:name).limit(3).to_a

    3.times do |i|
      event = MonitoringList::NotificationEvent.find_or_create_by!(
        organization: org,
        ml_name_snapshot: "Seed Notification #{i + 1}"
      ) { |e| e.changed_monitoring_list = monitoring_lists[i % monitoring_lists.size] }

      item = MonitoringList::NotificationItem.find_or_create_by!(
        event: event,
        membership: membership,
        organization: org
      )
      Inbox::Item.find_or_create_by!(itemable: item, membership: membership) { |record| record.organization = org }

      have = item.notification_revisions.count
      (TARGET_REVISIONS - have).times do |n|
        idx = have + n
        notification = notifications[idx % notifications.size]
        revision = MonitoringList::NotificationRevision.create!(
          notification: notification,
          history_summary: "Seed ##{i + 1} rev #{idx + 1}: #{notification.title} (#{notification.priority}) changed",
          version_range: ((idx + 1)...(idx + 2))
        )
        item.notification_revisions << revision
      end
      puts("notification item #{i + 1}: #{item.notification_revisions.count} revisions")
    end

    org_membership_ids = Membership.where(organization: org).order(:id).pluck(:id)
    summaries = [
      {
        membership_ids: org_membership_ids.first(4) + [DELETED_MEMBERSHIP_ID],
        remind_until: Time.zone.local(2026, 9, 1)
      },
      { membership_ids: org_membership_ids.first(8), remind_until: Time.zone.local(2026, 10, 1) },
      { membership_ids: org_membership_ids, remind_until: Time.zone.local(2026, 11, 1) }
    ]

    summaries.each_with_index do |spec, i|
      summary = Membership::AdminExpirySummaryItem.find_or_create_by!(
        organization: org,
        remind_until: spec[:remind_until]
      ) { |s| s.membership_ids = spec[:membership_ids] }

      Inbox::Item.find_or_create_by!(itemable: summary, membership: membership) { |record| record.organization = org }
      puts("admin summary item #{i + 1}: #{summary.membership_ids.size} memberships")
    end
  end

  puts('done')
  raise(ActiveRecord::Rollback) if ENV['DRY_RUN']
end
