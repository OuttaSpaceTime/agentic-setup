# Idempotent dev seed: gives superuser_as_admin_in_a (Organization A) 3 ml_notification inbox
# items, each covering every case from openapi/components/schemas/vilocifyInboxNotificationEntry.yml
# (every priority, every remediation level, missing remediation, missing changes, a deleted
# notification) plus filler entries so each item spans several pages at the default page size of 20.
# The three items carry different revision counts and per-item-labelled entries so they are
# visibly distinct in the inbox, not clones.
#   bin/rails runner .solve/scripts/seed_notification_entries_pages.rb
#   DRY_RUN=1 bin/rails runner .solve/scripts/seed_notification_entries_pages.rb

ITEM_REVISION_COUNTS = [45, 60, 90].freeze

REMEDIATION_LEVEL_BY_ENUM_VALUE = {
  'Official Fix' => 'O',
  'Temporary Fix' => 'T',
  'Workaround' => 'W',
  'Unavailable' => 'U',
  'Not Defined' => 'X'
}.freeze

PRIORITIES = %w[critical major minor informational withdrawn].freeze

def cvss_vector_with_remediation_level(level)
  "CVSS:3.1/AV:N/AC:H/PR:N/UI:N/S:U/C:H/I:H/A:H/E:U/RL:#{level}/RC:C"
end

def find_or_create_notification(title:, priority:, cvss_vector: nil)
  Notification.find_or_create_by!(title: title) do |notification|
    notification.description = 'A new critical vulnerability was found in your monitored components.'
    notification.impact = 'Remote attackers may execute arbitrary code.'
    notification.solution_details = 'Upgrade to the latest version.'
    notification.vendor_affected_components = 'Example Vendor'
    notification.action = :apply_patch
    notification.priority = priority
    notification.third_party_published_on = Date.current
    notification.last_successful_sync_at = Time.current
    notification.tlp_amber_strict = false
    notification.cvss_vector = cvss_vector
    notification.attack_vector = 'network' if cvss_vector
  end
end

def ensure_membership_limit(organization)
  period = organization.current_consumption_period ||
    organization.consumption_periods.create!(period: Date.current..1.year.from_now.to_date)
  period.orders.create!(name: 'Individual', membership_request_credit: 5) if period.membership_order_count < 5
end

def add_revision(notification_item, notification:, version_range:, history_summary:)
  revision = Inbox::Item::MonitoringList::Notification::Revision.create!(
    notification: notification,
    version_range: version_range,
    history_summary: history_summary
  )
  notification_item.notification_revisions << revision
  revision
end

def seed_edge_case_revisions(notification_item, label)
  # One entry per priority, each carrying a distinct remediation level (or none for informational).
  PRIORITIES.zip(REMEDIATION_LEVEL_BY_ENUM_VALUE.values).each do |priority, level|
    cvss_vector = priority == 'informational' ? nil : cvss_vector_with_remediation_level(level)
    notification = find_or_create_notification(
      title: "#{label}: #{priority.titleize} priority notification",
      priority: priority,
      cvss_vector: cvss_vector
    )
    add_revision(
      notification_item,
      notification: notification,
      version_range: 1..1,
      history_summary: "History for #{priority} priority"
    )
  end

  # Every remediation level explicitly, independent of priority.
  REMEDIATION_LEVEL_BY_ENUM_VALUE.each do |enum_value, level|
    notification = find_or_create_notification(
      title: "#{label}: Notification with #{enum_value} remediation",
      priority: 'major',
      cvss_vector: cvss_vector_with_remediation_level(level)
    )
    add_revision(
      notification_item,
      notification: notification,
      version_range: 1..1,
      history_summary: "Remediation is #{enum_value}"
    )
  end

  # Blank history_summary: the "changes" attribute is omitted from the serialized entry.
  add_revision(
    notification_item,
    notification: find_or_create_notification(title: "#{label}: Notification without changes", priority: 'minor'),
    version_range: 1..1,
    history_summary: ''
  )

  # Multi-version range with a multi-line history_summary.
  add_revision(
    notification_item,
    notification: find_or_create_notification(
      title: "#{label}: Notification with resend history",
      priority: 'critical'
    ),
    version_range: 1..4,
    history_summary: "Increased priority level\nUse Firefox instead"
  )

  # Deleted notification: the revision survives, but the entry collapses to `deleted: true` only.
  deleted_notification = find_or_create_notification(
    title: "#{label}: Notification pending deletion",
    priority: 'major'
  )
  add_revision(
    notification_item,
    notification: deleted_notification,
    version_range: 1..1,
    history_summary: 'This notification will be deleted'
  )
  deleted_notification.destroy!
end

def find_or_create_notification_item(organization, membership, index)
  monitoring_list = MonitoringList.find_or_create_by!(
    organization: organization,
    name: "Notification List #{index + 1}"
  )
  event = Inbox::Event::MonitoringList::Notification.find_or_create_by!(
    organization: organization,
    changed_monitoring_list: monitoring_list,
    ml_name_snapshot: monitoring_list.name
  )
  Inbox::Item::MonitoringList::Notification.find_or_create_by!(
    event: event,
    membership: membership,
    organization: organization
  )
end

Current.without_organization_and_membership_scopes do
  ActiveRecord::Base.transaction do
    organization = Organization.find_or_create_by!(name: 'Organization A')
    ensure_membership_limit(organization)

    user = User.find_or_create_by!(email: 'superuser@example.com') { |u| u.name = 'Super User' }
    membership = Membership.find_or_create_by!(user: user, organization: organization, role: 'admin') do |m|
      m.invitation_state = 'accepted'
    end

    ITEM_REVISION_COUNTS.each_with_index do |target_count, index|
      label = "Item #{index + 1}"
      notification_item = find_or_create_notification_item(organization, membership, index)
      inbox_item = notification_item.item ||
        notification_item.create_item!(membership: membership, organization: organization, read: false)

      revision_count = notification_item.notification_revisions.count
      if revision_count >= target_count
        puts("#{label}: Inbox::Item #{inbox_item.id} already has #{revision_count} revisions")
        next
      end

      seed_edge_case_revisions(notification_item, label)

      filler_notification = find_or_create_notification(
        title: "#{label}: Filler notification",
        priority: 'informational'
      )
      (target_count - notification_item.notification_revisions.count).times do |i|
        add_revision(
          notification_item,
          notification: filler_notification,
          version_range: 1..1,
          history_summary: "#{label} filler change ##{i + 1}"
        )
      end

      puts("#{label}: Inbox::Item #{inbox_item.id} now has #{notification_item.notification_revisions.count} revisions")
    end

    raise(ActiveRecord::Rollback) if ENV['DRY_RUN']
  end
end
