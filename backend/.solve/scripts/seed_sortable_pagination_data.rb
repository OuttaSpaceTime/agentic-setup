# Seeds every keyset-paginated collection endpoint with multi-page, outlier-rich sort data.
# Rerunnable: destroys only what a previous run of this script created (reserved id range or
# SEED_MARKER), then recreates it.
#
#   DRY_RUN=1 bin/rails runner .solve/scripts/seed_sortable_pagination_data.rb
#   bin/rails runner .solve/scripts/seed_sortable_pagination_data.rb

ActiveJob::Base.queue_adapter = :test

SEED_MARKER = '[keyset-sort-seed]'.freeze
TARGET = 130

# Index ranges shaping the value ladder. A run of 60 identical values cannot fit inside a
# 50-record page, so every tie run is guaranteed to straddle a page boundary.
NULL_RUN = (0...4)
TIE_RUN = (30...90)
LATE_NULL_RUN = (95...115)

# components carries a unique index on (name, version_info, vendor) for active rows, so each of the
# three gets its own tie run and the triple never ties on all of them at once.
NAME_TIE_RUN = (10...70)
VENDOR_TIE_RUN = (60...120)
VERSION_TIE_RUN = (0...60)

COMPONENT_ID_BASE = 2_000_000_000
NOTIFICATION_ID_BASE = 2_100_000_000
INBOX_ITEMABLE_ID_BASE = 2_200_000_000

# The inbox pages items and entries at 20, so every item type and every item carrying entries gets a
# second page, also under filter[itemType].
INBOX_ITEMS_PER_TYPE = 25
INBOX_ENTRIES_PER_ITEM = 25

COLLATION_OUTLIERS = {
  4 => ' leading space',
  5 => '0 leading digit',
  6 => '9 leading digit',
  7 => 'apple',
  8 => 'Apple',
  9 => 'APPLE',
  10 => 'Ärger',
  11 => 'ätzend',
  12 => 'Zebra',
  13 => '_underscore',
  14 => '-dash',
  15 => "tab\tinside",
  16 => 'a' * 200
}.freeze

# User#siemensid_limits rejects underscores, control characters and long names on create.
SIEMENSID_SAFE_OUTLIERS = COLLATION_OUTLIERS.except(13, 15, 16).freeze

def sortable_string(index, prefix, blank: '', tie_run: TIE_RUN, outliers: COLLATION_OUTLIERS)
  return blank if NULL_RUN.cover?(index) || LATE_NULL_RUN.cover?(index)
  return "#{prefix} tie value" if tie_run.cover?(index)

  outliers[index] || format('%s %03d', prefix, index)
end

def sortable_date(index, base)
  return nil if NULL_RUN.cover?(index) || LATE_NULL_RUN.cover?(index)
  return base if TIE_RUN.cover?(index)

  base + index.days
end

def sortable_time(index, base)
  return base - 1.year if NULL_RUN.cover?(index) || LATE_NULL_RUN.cover?(index)
  return base if TIE_RUN.cover?(index)

  base + index.minutes
end

organization = Current.without_organization_and_membership_scopes { Organization.find_by!(name: 'Organization A') }
seed_membership = Current.without_organization_and_membership_scopes do
  Membership.find_by!(organization: organization, role: 'admin', user: User.find_by!(email: 'superuser@example.com'))
end
base_time = Time.current.beginning_of_day - 1.year
base_date = Date.current - 200
eol_base_date = Date.current - 65

# Current.set has to wrap the transaction, not the other way round: after_commit callbacks run once
# the transaction closes, and Inbox::Item#membership resolves to nil outside the org scope.
Current.set(organization: organization, membership: seed_membership) do
  ActiveRecord::Base.transaction do
    period = organization.current_consumption_period ||
      organization.consumption_periods.create!(period: Date.current..1.year.from_now.to_date)
    needed = organization.active_memberships.count + TARGET + 10
    if organization.membership_limit < needed
      period.orders.create!(
        name: SEED_MARKER,
        membership_request_credit: needed
      )
    end

    seeded_component_ids = (COMPONENT_ID_BASE...(COMPONENT_ID_BASE + TARGET)).to_a
    seeded_notification_ids = (NOTIFICATION_ID_BASE...(NOTIFICATION_ID_BASE + TARGET)).to_a
    seeded_itemable_ids = (INBOX_ITEMABLE_ID_BASE...(INBOX_ITEMABLE_ID_BASE + 10_000))

    # dependent: :destroy runs Item -> itemable, never the other way, so the items have to go first
    # or destroying the events leaves them behind with a dangling itemable_id. This runs before the
    # components are destroyed, since their FKs nullify the component_id the events are found by.
    Inbox::Item.where(membership: seed_membership, itemable_id: seeded_itemable_ids).destroy_all
    Inbox::Item.where(
      itemable_type: 'Inbox::Item::MonitoringList::Notification',
      itemable_id: Inbox::Item::MonitoringList::Notification.where(
        event_id: Inbox::Event::MonitoringList::Notification.where(ml_name_snapshot: SEED_MARKER).select(:id)
      ).select(:id)
    ).destroy_all
    Inbox::Item.where(membership: seed_membership, itemable_type: 'Inbox::Item::MonitoringList::Notification')
      .where.not(itemable_id: Inbox::Item::MonitoringList::Notification.select(:id))
      .destroy_all
    Inbox::Event::MonitoringList::Notification.where(ml_name_snapshot: SEED_MARKER).destroy_all
    Inbox::Item::MonitoringList::Notification::Revision.where('history_summary LIKE ?', "#{SEED_MARKER}%").destroy_all
    Inbox::Event::MonitoringList::BasicDataUpdated.where(old_name: SEED_MARKER).destroy_all
    Inbox::Event::MonitoringList::ComponentsUpdated.where(ml_name_snapshot: SEED_MARKER).destroy_all
    Inbox::Event::MonitoringList::Deleted.where(ml_name_snapshot: SEED_MARKER).destroy_all
    Inbox::Event::MonitoringList::DependenciesChanged.where(ml_name_snapshot: SEED_MARKER).destroy_all
    Inbox::Event::MonitoringList::ComponentEol.where(component_id: seeded_component_ids).destroy_all
    Inbox::Event::Component::SupportDropped.where(component_id: seeded_component_ids).destroy_all

    MonitoringList.where(comment: SEED_MARKER).destroy_all
    ComponentRequest.where(comment: SEED_MARKER).destroy_all
    ApiToken.unscoped.where('name LIKE ?', "#{SEED_MARKER}%").destroy_all
    Membership.where(user: User.where('email LIKE ?', 'keyset-sort-seed-%')).destroy_all
    User.where('email LIKE ?', 'keyset-sort-seed-%').destroy_all
    Notification.unscoped.where(id: seeded_notification_ids).destroy_all
    Component.unscoped.where(id: seeded_component_ids).destroy_all

    # --- Component: /components, /monitoring_lists/:id/components, /notifications/:id/components
    # Empty name/vendor/version are only valid while inactive, so the blank outliers are deactivated.
    components = TARGET.times.map do |index|
      blank = NULL_RUN.cover?(index) || LATE_NULL_RUN.cover?(index)
      Component.create!(
        id: COMPONENT_ID_BASE + index,
        name: sortable_string(index, 'Seed Component', tie_run: NAME_TIE_RUN),
        vendor: sortable_string(index, 'Seed Vendor', tie_run: VENDOR_TIE_RUN),
        version_info: sortable_string(index, 'Seed Version', tie_run: VERSION_TIE_RUN),
        url: sortable_string(index, 'https://seed.example/component'),
        active: !blank,
        # A missing eol_date means "reached, date unknown" (-infinity) when eol_reached, else infinity.
        eol_date: sortable_date(index, eol_base_date),
        eol_reached: NULL_RUN.cover?(index),
        deletion_date: blank ? nil : sortable_time(index, base_time),
        deletion_reason: sortable_string(index, 'Seed Reason'),
        tlp_amber_strict: false,
        last_successful_sync_at: base_time,
        created_at: sortable_time(index, base_time),
        updated_at: sortable_time(index, base_time)
      )
    end

    # --- Notification: /notifications, /components/:id/notifications
    notifications = TARGET.times.map do |index|
      Notification.create!(
        id: NOTIFICATION_ID_BASE + index,
        title: sortable_string(index, 'Seed Notification', blank: format('Seed Notification blank %03d', index)),
        priority: Notification.priorities.keys[index % Notification.priorities.size],
        action: Notification.actions.keys[index % Notification.actions.size],
        description: SEED_MARKER,
        solution_details: SEED_MARKER,
        impact: SEED_MARKER,
        vendor_affected_components: SEED_MARKER,
        third_party_published_on: sortable_date(index, base_date) || base_date,
        tlp_amber_strict: false,
        last_successful_sync_at: base_time,
        created_at: sortable_time(index, base_time),
        updated_at: sortable_time(index, base_time)
      )
    end

    pivot_component = components.first
    pivot_notification = notifications.first

    NotificationComponentAssignment.insert_all(
      notifications.map { |notification| { notification_id: notification.id, component_id: pivot_component.id } } +
        components.drop(1).map { |component| { notification_id: pivot_notification.id, component_id: component.id } }
    )

    # --- Notification::Vulnerability: /vulnerabilities, /notifications/:id/vulnerabilities
    Notification::Vulnerability.insert_all(
      TARGET.times.map do |index|
        {
          notification_id: pivot_notification.id,
          vuln_id: 1_000_000 + index,
          cve: sortable_string(index, 'CVE-2024'),
          cwe: sortable_string(index, 'CWE'),
          created_at: sortable_time(index, base_time)
        }
      end
    )

    # --- MonitoringList: /monitoring_lists, /components/:id/monitoring_lists, parents, children
    monitoring_lists = TARGET.times.map do |index|
      MonitoringList.create!(
        name: sortable_string(index, 'Seed List', blank: format('Seed List blank %03d', index)),
        comment: SEED_MARKER,
        organization: organization,
        created_at: sortable_time(index, base_time),
        updated_at: sortable_time(index, base_time)
      )
    end

    pivot_list = monitoring_lists.first
    MonitoringListsComponent.insert_all(
      components.map do |component|
        { monitoring_list_id: pivot_list.id, component_id: component.id, organization_id: organization.id }
      end +
        monitoring_lists.drop(1).map do |list|
          { monitoring_list_id: list.id, component_id: pivot_component.id, organization_id: organization.id }
        end
    )

    # pivot_list gets every other list as a child; the last list gets every other one as a parent.
    parent_pivot_list = monitoring_lists.last
    MonitoringListMonitoringListRelation.insert_all(
      monitoring_lists.drop(1).map do |list|
        { monitoring_list_from_id: pivot_list.id, monitoring_list_to_id: list.id, organization_id: organization.id }
      end +
        monitoring_lists[1...-1].map do |list|
          {
            monitoring_list_from_id: list.id,
            monitoring_list_to_id: parent_pivot_list.id,
            organization_id: organization.id
          }
        end
    )

    # --- ComponentRequest: /component_requests, /monitoring_lists/:id/component_requests
    # component_name and version have a minimum length, so their blank outlier is a single space.
    component_requests = TARGET.times.map do |index|
      ComponentRequest.create!(
        component_name: sortable_string(index, 'Seed Request', blank: ' '),
        version: sortable_string(index, 'Seed CR Version', blank: ' '),
        vendor: sortable_string(index, 'Seed CR Vendor'),
        url: sortable_string(index, 'https://seed.example/cr', blank: 'https://seed.example/fallback'),
        security_url: sortable_string(index, 'https://seed.example/security'),
        comment: SEED_MARKER,
        membership: seed_membership,
        organization: organization,
        created_at: sortable_time(index, base_time),
        updated_at: sortable_time(index, base_time)
      )
    end

    MonitoringListsComponentRequest.insert_all(
      component_requests.map do |request|
        {
          monitoring_list_id: pivot_list.id,
          component_request_id: request.id,
          organization_id: organization.id,
          created_at: base_time,
          updated_at: base_time
        }
      end
    )

    # --- Membership: /memberships
    roles = Membership.roles.keys
    memberships = TARGET.times.map do |index|
      blank = NULL_RUN.cover?(index) || LATE_NULL_RUN.cover?(index)
      user = User.create!(
        email: format('keyset-sort-seed-%03d@example.test', index),
        name: blank ? nil : sortable_string(index, 'Seed User', outliers: SIEMENSID_SAFE_OUTLIERS)
      )
      Membership.create!(
        user: user,
        organization: organization,
        role: roles[index % roles.size],
        invitation_state: Membership.invitation_states.keys[index % Membership.invitation_states.size],
        expires_at: sortable_date(index, Date.current + 30)&.to_time,
        created_at: sortable_time(index, base_time),
        updated_at: sortable_time(index, base_time)
      )
    end

    # --- Subscription: /subscriptions, /monitoring_lists/:id/subscriptions
    Subscription.insert_all(
      monitoring_lists.map.with_index do |list, index|
        {
          monitoring_list_id: list.id,
          membership_id: seed_membership.id,
          organization_id: organization.id,
          role: index.even? ? Subscription::OWNER : Subscription::READER,
          created_at: sortable_time(index, base_time),
          updated_at: sortable_time(index, base_time)
        }
      end +
        memberships.map.with_index do |membership, index|
          {
            monitoring_list_id: pivot_list.id,
            membership_id: membership.id,
            organization_id: organization.id,
            role: index.even? ? Subscription::OWNER : Subscription::READER,
            created_at: sortable_time(index, base_time),
            updated_at: sortable_time(index, base_time)
          }
        end
    )

    # --- ApiToken: /api_tokens. Capped at 50 per membership by PER_USER_TOKEN_LIMIT, and
    # expires_on must stay within [today, today + 1 year], so this collection only pages at a
    # small page[size]. The count stays under the cap so a token can still be minted by hand.
    token_count = 40
    token_count.times do |index|
      ApiToken.create!(
        name: format('%s token %03d', SEED_MARKER, index),
        description: sortable_string(index, 'Seed Token'),
        expires_on: TIE_RUN.cover?(index) ? Date.current + 100 : Date.current + (index % 360),
        membership: seed_membership,
        created_at: sortable_time(index, base_time)
      )
    end

    # --- Inbox::Item: /inbox/items
    create_inbox_item = lambda do |itemable, index|
      Inbox::Item.create!(
        itemable: itemable,
        membership: seed_membership,
        organization: organization,
        created_at: sortable_time(index, base_time),
        updated_at: sortable_time(index, base_time)
      )
    end
    itemable_ids = seeded_itemable_ids.each

    revisions = INBOX_ENTRIES_PER_ITEM.times.map do |index|
      Inbox::Item::MonitoringList::Notification::Revision.create!(
        notification: notifications[index],
        version_range: 1..2,
        history_summary: format('%s revision %03d', SEED_MARKER, index),
        created_at: sortable_time(index, base_time),
        updated_at: sortable_time(index, base_time)
      )
    end

    TARGET.times do |index|
      event = Inbox::Event::MonitoringList::Notification.create!(
        organization: organization,
        ml_name_snapshot: SEED_MARKER,
        changed_monitoring_list: pivot_list
      )
      itemable = Inbox::Item::MonitoringList::Notification.create!(
        event: event, membership: seed_membership, organization: organization
      )
      Inbox::Item::MonitoringList::Notification::RevisionLink.insert_all(
        revisions.map { |revision| { item_id: itemable.id, revision_id: revision.id } }
      )
      create_inbox_item.call(itemable, index)
    end

    [
      Inbox::Item::ComponentRequest::Changed::Processed,
      Inbox::Item::ComponentRequest::Changed::Updated
    ].each do |item_class|
      INBOX_ITEMS_PER_TYPE.times do |index|
        request = component_requests[index]
        component = components[index + 20]
        itemable = item_class.create!(
          id: itemable_ids.next,
          organization: organization,
          component_request: request,
          cr_component_name: request.component_name,
          cr_vendor_name: request.vendor,
          cr_version_info: request.version,
          cr_url: request.url,
          component_id: component.id.to_s,
          component_component_name: component.name,
          component_vendor_name: component.vendor,
          component_version_info: component.version_info,
          component_url: component.url,
          rejection_reasons: index.even? ? [] : ['Seed rejection reason']
        )
        create_inbox_item.call(itemable, index)
      end
    end

    INBOX_ITEMS_PER_TYPE.times do |index|
      component = components[index + 20]
      event = Inbox::Event::Component::SupportDropped.create!(
        component: component,
        component_name: component.name,
        vendor_name: component.vendor,
        version_info: component.version_info,
        url: component.url,
        deletion_date: component.deletion_date,
        deletion_reason: component.deletion_reason
      )
      itemable = Inbox::Item::Component::SupportDropped.create!(
        id: itemable_ids.next, event: event, organization: organization, monitoring_list_ids: [pivot_list.id]
      )
      create_inbox_item.call(itemable, index)
    end

    INBOX_ITEMS_PER_TYPE.times do |index|
      itemable = Inbox::Item::Membership::ExpirySummary.create!(
        id: itemable_ids.next, organization: organization, remind_until: 3.weeks.from_now
      )
      Inbox::Item::Membership::ExpirySummary::Entry.insert_all(
        memberships.first(INBOX_ENTRIES_PER_ITEM).map.with_index do |membership, entry_index|
          {
            expiry_summary_id: itemable.id,
            membership_id: membership.id,
            created_at: sortable_time(entry_index, base_time),
            updated_at: sortable_time(entry_index, base_time)
          }
        end
      )
      create_inbox_item.call(itemable, index)
    end

    INBOX_ITEMS_PER_TYPE.times do |index|
      list = monitoring_lists[index]
      event = Inbox::Event::MonitoringList::BasicDataUpdated.create!(
        organization: organization,
        changed_monitoring_list: list,
        actor: seed_membership,
        old_name: SEED_MARKER,
        new_name: list.name,
        old_comment: SEED_MARKER,
        new_comment: SEED_MARKER
      )
      itemable = Inbox::Item::MonitoringList::BasicDataUpdated.create!(
        id: itemable_ids.next, event: event, organization: organization
      )
      create_inbox_item.call(itemable, index)
    end

    [true, false].each do |eol_reached|
      INBOX_ITEMS_PER_TYPE.times do |index|
        event = Inbox::Event::MonitoringList::ComponentEol.create!(component: components[index + 20])
        # before_create snapshots eol_reached from the component, which is false for every seeded one here.
        event.update_column(:eol_reached, eol_reached)
        itemable = Inbox::Item::MonitoringList::ComponentEol.create!(
          id: itemable_ids.next,
          event: event,
          membership: seed_membership,
          organization: organization,
          monitoring_list_ids: [pivot_list.id]
        )
        create_inbox_item.call(itemable, index)
      end
    end

    INBOX_ITEMS_PER_TYPE.times do |index|
      event = Inbox::Event::MonitoringList::ComponentsUpdated.create!(
        organization: organization,
        changed_monitoring_list: pivot_list,
        actor: seed_membership,
        ml_name_snapshot: SEED_MARKER,
        added_component_ids: [components[index + 20].id]
      )
      itemable = Inbox::Item::MonitoringList::ComponentsUpdated.create!(
        id: itemable_ids.next, event: event, organization: organization
      )
      create_inbox_item.call(itemable, index)
    end

    INBOX_ITEMS_PER_TYPE.times do |index|
      event = Inbox::Event::MonitoringList::Deleted.create!(
        organization: organization, actor: seed_membership, ml_name_snapshot: SEED_MARKER
      )
      itemable = Inbox::Item::MonitoringList::Deleted.create!(
        id: itemable_ids.next, event: event, organization: organization
      )
      create_inbox_item.call(itemable, index)
    end

    [
      [Inbox::Event::MonitoringList::DependenciesChanged::Created, Inbox::Item::MonitoringList::DependenciesChanged::Created],
      [Inbox::Event::MonitoringList::DependenciesChanged::Removed, Inbox::Item::MonitoringList::DependenciesChanged::Removed]
    ].each do |event_class, item_class|
      INBOX_ITEMS_PER_TYPE.times do |index|
        event = event_class.create!(
          organization: organization,
          changed_monitoring_list: pivot_list,
          actor: seed_membership,
          ml_name_snapshot: SEED_MARKER,
          dependency_ids: [monitoring_lists[index + 1].id]
        )
        itemable = item_class.create!(id: itemable_ids.next, event: event, organization: organization)
        create_inbox_item.call(itemable, index)
      end
    end

    [
      Inbox::Item::MonitoringList::SubscriptionChanged::Added,
      Inbox::Item::MonitoringList::SubscriptionChanged::Removed,
      Inbox::Item::MonitoringList::SubscriptionChanged::Updated
    ].each do |item_class|
      INBOX_ITEMS_PER_TYPE.times do |index|
        itemable = item_class.create!(
          id: itemable_ids.next,
          organization: organization,
          changed_monitoring_list: monitoring_lists[index],
          actor: seed_membership,
          ml_name_snapshot: SEED_MARKER,
          role_before: Subscription::READER,
          role_after: Subscription::OWNER
        )
        create_inbox_item.call(itemable, index)
      end
    end

    # --- MonitoringList::Export: /exports. MAX_DAILY_EXPORTS caps a membership at 50 per rolling
    # day, so batches are backdated out of the window before the next one is created.
    seed_membership.exports.destroy_all
    export_ids = []
    TARGET.times.each_slice(40) do |slice|
      MonitoringList::Export.where(id: export_ids).update_all(created_at: 2.days.ago)
      slice.each do |index|
        export = MonitoringList::Export.create!(membership: seed_membership, state: 'success')
        export.update_columns(created_at: sortable_time(index, base_time), updated_at: sortable_time(index, base_time))
        export_ids << export.id
      end
    end

    puts(format('%-24s %s', 'components', Component.where(id: seeded_component_ids).count))
    puts(format('%-24s %s', 'notifications', Notification.where(id: seeded_notification_ids).count))
    puts(
      format(
        '%-24s %s',
        'vulnerabilities',
        Notification::Vulnerability.where(notification: pivot_notification).count
      )
    )
    puts(format('%-24s %s', 'monitoring_lists', MonitoringList.where(comment: SEED_MARKER).count))
    puts(format('%-24s %s', 'component_requests', ComponentRequest.where(comment: SEED_MARKER).count))
    puts(
      format(
        '%-24s %s',
        'memberships',
        Membership.where(user: User.where('email LIKE ?', 'keyset-sort-seed-%')).count
      )
    )
    puts(format('%-24s %s', 'subscriptions', Subscription.where(monitoring_list: pivot_list).count))
    puts(format('%-24s %s', 'api_tokens', ApiToken.where('name LIKE ?', "#{SEED_MARKER}%").count))
    puts(format('%-24s %s', 'inbox_items', Inbox::Item.where(membership: seed_membership).count))
    Inbox::Item.where(membership: seed_membership).group(:item_type_cache).order(:item_type_cache).count
      .each { |item_type, count| puts(format('  %-40s %s', item_type, count)) }
    puts(format('%-24s %s', 'exports', seed_membership.exports.count))
    puts(format('%-24s %s', 'pivot monitoring_list', pivot_list.id))
    puts(format('%-24s %s', 'pivot component', pivot_component.id))
    puts(format('%-24s %s', 'pivot notification', pivot_notification.id))
    puts(format('%-24s %s', 'parent pivot list', parent_pivot_list.id))

    raise(ActiveRecord::Rollback) if ENV['DRY_RUN']
  end
end
