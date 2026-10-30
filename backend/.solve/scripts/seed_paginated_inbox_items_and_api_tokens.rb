TARGET_INBOX_ITEMS = 100
TARGET_SEED_TOKENS = 49

org = Current.without_organization_and_membership_scopes { Organization.find_by!(name: 'Organization A') }
superuser = User.find_by!(email: 'superuser@example.com')
membership = Current.without_organization_and_membership_scopes do
  Membership.find_by!(organization: org, user: superuser, role: 'admin')
end

ActiveRecord::Base.transaction do
  Current.set(organization: org, membership: membership) do
    monitoring_list = MonitoringList.order(:name).first!
    seeded_at = Time.current - (TARGET_INBOX_ITEMS + 1).minutes

    TARGET_INBOX_ITEMS.times do |i|
      label = format('Seed Inbox %03d', i + 1)
      event = Inbox::Event::MonitoringList::Notification.find_or_create_by!(
        organization: org,
        ml_name_snapshot: label
      ) { |record| record.changed_monitoring_list = monitoring_list }

      itemable = Inbox::Item::MonitoringList::Notification.find_or_create_by!(
        event: event,
        membership: membership,
        organization: org
      )

      Inbox::Item.find_or_create_by!(itemable: itemable, membership: membership) do |record|
        record.organization = org
        record.created_at = seeded_at + i.minutes
        record.updated_at = seeded_at + i.minutes
      end
    end

    TARGET_SEED_TOKENS.times do |i|
      ApiToken.find_or_create_by!(name: format('Seed Token %02d', i + 1)) do |record|
        record.description = format('Seed API token %02d', i + 1)
        record.expires_on = Date.current + (i + 1).days
        record.created_at = seeded_at + i.minutes
        record.updated_at = seeded_at + i.minutes
      end
    end

    item_count = Inbox::Item.where(membership: membership).count
    token_count = ApiToken.count
    puts("inbox items: #{item_count} (#{item_count.fdiv(20).ceil} pages of 20)")
    puts("api tokens:  #{token_count} (#{token_count.fdiv(20).ceil} pages of 20)")
    raise(ActiveRecord::Rollback) if ENV['DRY_RUN']
  end
end
